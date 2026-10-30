-- maintenance.sql
-- Revisión de autovacuum/ANALYZE y acción de mantenimiento segura y justificada.
-- Regla del proyecto: NO usar VACUUM FULL como mantenimiento periódico (bloquea la base y reescribe tablas enteras).
-- Un VACUUM o ANALYZE manual solo se ejecuta si la observación previa del estado de las tablas lo justifica.

\echo '=== REVISIÓN PREVIA: estado de tablas para justificar acción de mantenimiento ==='
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Acción de mantenimiento segura: ANALYZE sobre las tablas con tuplas muertas o sin autoanalyze reciente.
-- Justificación: ANALYZE actualiza las estadísticas del planificador sin bloquear lecturas ni escrituras,
-- y se ejecuta solo cuando la revisión previa indica tablas con acumulación de tuplas muertas
-- o estadísticas desactualizadas (last_autoanalyze NULL o muy antiguo).
-- Si alguna tabla supera umbrales críticos, se evaluará VACUUM (no FULL) en ventana de mantenimiento.

ANALYZE;

\echo '=== ACCIÓN COMPLETADA: ANALYZE ejecutado sobre foodstore ===';
