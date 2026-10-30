-- health_check.sql
-- Chequeo de salud de la base foodstore (PostgreSQL 16+)
-- Ejecutar con un usuario con privilegios de lectura sobre pg_stat_* y pg_database.
-- Cuatro controles mínimos: tamaño de la base, actividad de conexiones, estado de tablas y consultas activas.

\echo '=== CONTROL 1: Tamaño de la base foodstore ==='
SELECT pg_size_pretty(pg_database_size('foodstore')) AS tamano;

\echo '=== CONTROL 2: Actividad de conexiones ==='
SELECT numbackends, xact_commit, xact_rollback
FROM pg_stat_database
WHERE datname = 'foodstore';

\echo '=== CONTROL 3: Estado de tablas (tuplas muertas y autovacuum/autoanalyze) ==='
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '=== CONTROL 4: Consultas activas (no idle) en foodstore ==='
SELECT pid, state, now() - query_start AS duracion, query
FROM pg_stat_activity
WHERE datname = 'foodstore' AND state <> 'idle';
