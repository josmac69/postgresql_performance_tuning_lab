-- reset_stats.sql
-- Resets all gathered statistics in pg_stat_statements.

\echo 'Resetting pg_stat_statements...'
SELECT pg_stat_statements_reset();
\echo 'Statistics reset complete!'
