-- analyze_queries.sql
-- Diagnostics script to query pg_stat_statements and identify bottlenecks.

-- Enable psql timing output
\timing on

\echo '----------------------------------------------------------------------'
\echo '1. Top 5 Queries by Total Execution Time (Most CPU/IO Consuming)'
\echo '----------------------------------------------------------------------'
SELECT 
    queryid,
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(min_exec_time::numeric, 2) AS min_time_ms,
    round(max_exec_time::numeric, 2) AS max_time_ms,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct_of_total_time,
    query AS full_query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '2. Top 5 Queries by Mean (Average) Execution Time (Highest Latency)'
\echo '----------------------------------------------------------------------'
SELECT 
    queryid,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
    round(min_exec_time::numeric, 2) AS min_time_ms,
    round(max_exec_time::numeric, 2) AS max_time_ms,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    query AS full_query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '3. Top 5 Queries by Shared Buffer Disk Reads (High Disk I/O Pressure)'
\echo '----------------------------------------------------------------------'
SELECT 
    queryid,
    calls,
    shared_blks_read AS blocks_read_from_disk,
    shared_blks_hit AS blocks_hit_in_cache,
    round((100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio_pct,
    query AS full_query
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '4. Planning Time vs Execution Time Analysis (Planning Overhead)'
\echo '----------------------------------------------------------------------'
SELECT 
    queryid,
    plans,
    round(total_plan_time::numeric, 2) AS total_plan_time_ms,
    round(mean_plan_time::numeric, 2) AS mean_plan_time_ms,
    calls,
    round(total_exec_time::numeric, 2) AS total_exec_time_ms,
    round((100.0 * total_plan_time / nullif(total_plan_time + total_exec_time, 0))::numeric, 2) AS planning_overhead_pct,
    query AS full_query
FROM pg_stat_statements
WHERE plans > 0
ORDER BY total_plan_time DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '5. Query Health Warnings & Optimization Flags (Bottlenecks to Check)'
\echo '----------------------------------------------------------------------'
SELECT 
    queryid,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    CASE 
        WHEN temp_blks_written > 0 THEN 'TEMP FILE SPILL'
        WHEN shared_blks_read > 500 AND (shared_blks_hit::double precision / nullif(shared_blks_hit + shared_blks_read, 0)) < 0.95 THEN 'HIGH DISK I/O'
        WHEN mean_exec_time > 15 THEN 'HIGH LATENCY'
        WHEN max_exec_time > 100 AND max_exec_time > 5 * mean_exec_time THEN 'HIGH LATENCY VARIANCE'
        WHEN total_plan_time > 0.15 * (total_plan_time + total_exec_time) AND calls > 50 THEN 'HIGH PLANNING OVERHEAD'
        ELSE 'NOTICE'
    END AS warning_flag,
    CASE 
        WHEN temp_blks_written > 0 THEN 'Hash/Sort spilled to temp files. Increase work_mem configuration.'
        WHEN shared_blks_read > 500 AND (shared_blks_hit::double precision / nullif(shared_blks_hit + shared_blks_read, 0)) < 0.95 THEN 'Low cache hit ratio with disk reads. Check for missing indexes or table scans.'
        WHEN mean_exec_time > 15 THEN 'Query is slow on average. Run EXPLAIN ANALYZE to identify sequential scans.'
        WHEN max_exec_time > 100 AND max_exec_time > 5 * mean_exec_time THEN 'Query performance is unstable. Check lock contention or parameter-sensitive plans.'
        WHEN total_plan_time > 0.15 * (total_plan_time + total_exec_time) AND calls > 50 THEN 'High planning time ratio. Use prepared statements or parameterize query constants.'
        ELSE 'Consider checking indexes or rewriting structure.'
    END AS recommended_action,
    substring(query, 1, 60) AS query_snippet
FROM pg_stat_statements
WHERE 
    temp_blks_written > 0 
    OR (shared_blks_read > 500 AND (shared_blks_hit::double precision / nullif(shared_blks_hit + shared_blks_read, 0)) < 0.95)
    OR mean_exec_time > 15
    OR (max_exec_time > 100 AND max_exec_time > 5 * mean_exec_time)
    OR (total_plan_time > 0.15 * (total_plan_time + total_exec_time) AND calls > 50)
ORDER BY mean_exec_time DESC;

