# SPEC_U6 — Plan de respaldo y restauración: Food Store

Motor: PostgreSQL 16 o superior | Base principal: `foodstore` | Base de restauración: `foodstore_restore_test`

## Reglas de seguridad
- La base `foodstore` **no se elimina ni se reemplaza** durante el simulacro.
- Las contraseñas **no se escriben en scripts ni se entregan al repositorio** (se resuelven mediante variable de entorno o archivo de conexión del entorno de ejecución).
- El respaldo se genera en **formato custom** (`-Fc`) para poder usar `pg_restore`.
- Las pruebas destructivas solo se ejecutan sobre el entorno descartable `foodstore_restore_test`.

## Automatización propuesta

| Tarea mínima | Frecuencia propuesta | Condición que confirma que terminó correctamente |
|---|---|---|
| Respaldo de `foodstore` | Diaria | Archivo `.dump` con fecha y hora en el nombre + registro en carpeta `logs/`; `pg_dump` finalizó con código de salida 0. |
| Chequeo de salud | Diaria | Ejecución de `health_check.sql` sin errores; salida revisada (tamaño de base, actividad de conexiones, estado de tablas, consultas activas). |
| Revisión de mantenimiento | Semanal | Ejecución de `maintenance.sql`: estado de tuplas muertas, autovacuum y estadísticas (`ANALYZE`); acciones registradas y justificadas por la observación previa. |
| Restauración de prueba | Semanal | `foodstore_restore_test` creada desde el último respaldo; conteos de filas comparados con el respaldo y restricciones lógicas (precio/stock/cantidad >= 0) devuelven cero registros inválidos. |

## Alcance
Se automatizan: generación del respaldo custom, chequeo de salud diario, revisión semanal de mantenimiento y restauración de prueba semanal en base descartable. Queda fuera de este plan la programación automática (cron / Task Scheduler) hasta que el equipo ejecute los scripts manualmente y los valide como aptos.

Referencias: PostgreSQL 16 — backup, pg_dump, pg_restore, monitoring y mantenimiento rutinario.
