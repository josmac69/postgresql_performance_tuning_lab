-- analyze_queries_pgsm.sql
-- Diagnostics script to query pg_stat_monitor and identify bottlenecks.

-- Enable psql timing output
\timing on

\echo '----------------------------------------------------------------------'
\echo '1. Top 5 Queries by Total Execution Time (pg_stat_monitor)'
\echo '----------------------------------------------------------------------'
SELECT 
    pgsm_query_id,
    queryid,
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
    round(min_exec_time::numeric, 2) AS min_time_ms,
    round(max_exec_time::numeric, 2) AS max_time_ms,
    application_name,
    substring(query, 1, 80) AS query_snippet
FROM pg_stat_monitor
ORDER BY total_exec_time DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '2. Query Performance Bucketed by Start Time (Time Series Trends)'
\echo '----------------------------------------------------------------------'
SELECT 
    pgsm_query_id,
    queryid,
    bucket,
    to_char(bucket_start_time, 'HH24:MI:SS') AS start_time,
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
    substring(query, 1, 60) AS query_snippet
FROM pg_stat_monitor
ORDER BY bucket_start_time DESC, total_exec_time DESC
LIMIT 10;

\echo '----------------------------------------------------------------------'
\echo '3. Client Metadata and Application Impact'
\echo '----------------------------------------------------------------------'
SELECT 
    coalesce(client_ip::text, 'local') AS client_ip,
    application_name,
    count(distinct pgsm_query_id) AS unique_queries,
    sum(calls) AS total_calls,
    round(sum(total_exec_time)::numeric, 2) AS total_time_ms,
    round(avg(mean_exec_time)::numeric, 2) AS avg_mean_latency_ms
FROM pg_stat_monitor
GROUP BY client_ip, application_name
ORDER BY total_time_ms DESC;

\echo '----------------------------------------------------------------------'
\echo '4. Relation (Table) Access Analysis (Unnested Relations Array)'
\echo '----------------------------------------------------------------------'
SELECT 
    unnest(relations) AS table_name,
    count(*) AS distinct_queries,
    sum(calls) AS total_calls,
    round(sum(total_exec_time)::numeric, 2) AS total_time_ms
FROM pg_stat_monitor
WHERE relations IS NOT NULL AND relations <> '{}'
GROUP BY table_name
ORDER BY total_time_ms DESC;

\echo '----------------------------------------------------------------------'
\echo '5. Top 3 Logged Query Execution Plans (Saved directly in pgsm)'
\echo '----------------------------------------------------------------------'
SELECT 
    pgsm_query_id,
    queryid,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
    substring(query, 1, 65) AS query_snippet,
    query_plan
FROM pg_stat_monitor
WHERE query_plan IS NOT NULL AND query_plan <> ''
ORDER BY mean_exec_time DESC
LIMIT 3;

\echo '----------------------------------------------------------------------'
\echo '6. pg_stat_monitor Health Warnings & Advanced Diagnostics'
\echo '----------------------------------------------------------------------'
SELECT 
    pgsm_query_id,
    queryid,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    CASE 
        WHEN query_plan LIKE '%Seq Scan%' AND NOT (query LIKE '%pg_stat%') THEN 'SEQ SCAN DETECTED'
        WHEN cpu_sys_time > 0.3 * nullif(cpu_user_time + cpu_sys_time, 0) THEN 'HIGH SYSTEM CPU'
        WHEN wal_bytes > 10000000 THEN 'HEAVY WAL WRITER'
        WHEN application_name IS NULL OR application_name = '' OR application_name = 'psql' THEN 'UNMANAGED CLIENT'
        WHEN cardinality(relations) > 3 THEN 'COMPLEX JOIN WORKLOAD'
        ELSE 'NOTICE'
    END AS warning_flag,
    CASE 
        WHEN query_plan LIKE '%Seq Scan%' AND NOT (query LIKE '%pg_stat%') THEN 'Query plan shows a sequential scan. Run EXPLAIN to check if indexes are missing.'
        WHEN cpu_sys_time > 0.3 * nullif(cpu_user_time + cpu_sys_time, 0) THEN 'High OS kernel CPU usage. Investigate system calls, disk wait, or swapping.'
        WHEN wal_bytes > 10000000 THEN 'Query generates substantial WAL volume (>10MB). Review write/update frequencies.'
        WHEN application_name IS NULL OR application_name = '' OR application_name = 'psql' THEN 'Query run from psql or anonymous client. Use application_name in connection strings.'
        WHEN cardinality(relations) > 3 THEN 'Query joins 4 or more tables. Check join order, indexes, or consider denormalization.'
        ELSE 'Query performance looks acceptable.'
    END AS recommended_action,
    substring(query, 1, 60) AS query_snippet
FROM pg_stat_monitor
WHERE 
    (query_plan LIKE '%Seq Scan%' AND NOT (query LIKE '%pg_stat%'))
    OR (cpu_sys_time > 0.3 * nullif(cpu_user_time + cpu_sys_time, 0))
    OR (wal_bytes > 10000000)
    OR (cardinality(relations) > 3)
ORDER BY mean_exec_time DESC
LIMIT 20;
