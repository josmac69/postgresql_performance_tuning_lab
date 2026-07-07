-- analyze_queries.sql
-- Diagnostics script to query pg_stat_statements and identify bottlenecks.

\echo '----------------------------------------------------------------------'
\echo '1. Top 5 Queries by Total Execution Time (Most CPU/IO Consuming)'
\echo '----------------------------------------------------------------------'
SELECT 
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
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
    calls,
    round(mean_exec_time::numeric, 2) AS mean_time_ms,
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
    calls,
    shared_blks_read AS blocks_read_from_disk,
    shared_blks_hit AS blocks_hit_in_cache,
    round((100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio_pct,
    query AS full_query
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 5;

\echo '----------------------------------------------------------------------'
\echo '4. Planning Time vs Execution Time Analysis'
\echo '----------------------------------------------------------------------'
SELECT 
    plans,
    round(total_plan_time::numeric, 2) AS total_plan_time_ms,
    round(mean_plan_time::numeric, 2) AS mean_plan_time_ms,
    calls,
    round(total_exec_time::numeric, 2) AS total_exec_time_ms,
    query AS full_query
FROM pg_stat_statements
WHERE plans > 0
ORDER BY total_plan_time DESC
LIMIT 5;
