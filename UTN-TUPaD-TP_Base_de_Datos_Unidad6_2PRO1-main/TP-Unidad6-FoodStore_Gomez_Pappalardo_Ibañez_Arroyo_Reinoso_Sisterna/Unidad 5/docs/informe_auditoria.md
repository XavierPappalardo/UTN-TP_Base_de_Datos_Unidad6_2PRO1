# Informe de auditoría — TP Unidad 5, Parte B

Grupo E: Gómez, Pappalardo, Reinoso, Ibáñez, Sisterna, Arroyo · 2026-10-15
Base: `food_store` (PostgreSQL 16.15, entorno de desarrollo propio, Windows).

## 1. Parámetros modificados (vía `ALTER SYSTEM` + `SELECT pg_reload_conf()`)

| Parámetro | Antes | Después | Contexto | Efecto |
|---|---|---|---|---|
| `log_connections` | `off` | `on` | superuser-backend | Registra cada intento de conexión (recibida, autenticada/autorizada o fallida). |
| `log_disconnections` | `off` | `on` | superuser-backend | Registra cada desconexión con duración de sesión. |
| `log_statement` | `none` | `mod` | superuser | Registra DDL + `INSERT/UPDATE/DELETE` (no `SELECT`). Nivel mínimo que cubre operaciones de modificación. |
| `log_line_prefix` | `%t` | `%m [%p] %u@%d %h ` | sighup | Agrega milisegundos, PID, `usuario@basedatos` y host origen: sin esto el log no dice **quién ni desde dónde**. |

Verificación: `SHOW` posterior confirma los 4 valores activos sin reiniciar
(el reload bastó). Los cambios quedan en `postgresql.auto.conf`; para
revertir: `ALTER SYSTEM RESET log_connections; …; SELECT pg_reload_conf();`.
`logging_collector` ya estaba en `on` y `log_destination=stderr`, por lo que
el log se escribe en `C:/Program Files/PostgreSQL/16/data/log/`.

## 2. Secuencia ejecutada (`sql/auditoria_test.sql` + shell)

1. **Lectura:** `SELECT id_producto, nombre, precio FROM producto LIMIT 3` → 3 filas.
2. **Inserción:** categoría `__TP_U5_AUDIT__` → `id_categoria = 7`.
3. **Actualización:** `stock_producto +1` y `-1` sobre producto 1 (revertido, sin efecto neto).
4. **Limpieza:** `DELETE FROM categoria WHERE nombre='__TP_U5_AUDIT__'` → `DELETE 0`
   (el trigger `fn_soft_delete` lo convirtió en `UPDATE eliminado=TRUE`; verificado: `eliminado=t`).
5. **Login fallido (shell aparte):** `psql -U app_web` con clave incorrecta → `FATAL: la autenticación password falló`.

Fragmento capturado: `docs/log_auditoria_prueba.txt` (22:18:07–22:18:38 /-03).

## 3. Qué es útil para auditoría y qué queda fuera (sobre el fragmento)

**Útil (quién/qué/cuándo/desde dónde):** cada línea trae milisegundos + PID
(`[8932]` permite seguir una sesión), `postgres@food_store` (quién y sobre qué
base), `::1` + puerto (desde dónde), el texto completo de cada sentencia de
modificación (qué: `INSERT…RETURNING`, ambos `UPDATE`, `DELETE`), la duración
de sesión al desconectar, y el login fallido con identidad intentada
(`app_web`), método (`scram-sha-256`) y regla `pg_hba` que lo evaluó.

**Fuera de alcance de este mecanismo nativo:** el `SELECT` de lectura **no**
aparece como sentencia (con `log_statement='mod'` solo se sabe que alguien se
conectó, no qué leyó); tampoco hay detalle fila por fila (¿qué valores viejos/
nuevos tenía `stock_producto`? ¿qué filas exactas tocó el `UPDATE`?), ni quién
ejecutó qué dentro de un *pooler* que comparte usuario, ni protección contra
manipulación del propio log. Para esa granularidad haría falta la extensión
`pgaudit` (clases de objetos + nivel `read/write`, registro por objeto
accedido) o triggers de auditoría por tabla —a nivel de nociones: `pgaudit`
dice *qué objeto se tocó y con qué sentencia*, pero tampoco guarda
valores antes/después; eso ya es auditoría aplicativa.

## 4. ¿El propio archivo de log es un activo sensible?

**Sí.** El log concentra usuarios, hosts, horarios de actividad, esquemas,
sentencias con literales (mails, valores, IDs) y evidencia de intentos de
acceso: es un mapa del sistema útil para un atacante y, a la vez, la prueba
para rendir cuentas. Debe leerlo solo el rol de administración/DBA y
auditoría (`rol_auditor` a nivel lógico): a nivel de SO, archivo propiedad de
la cuenta de servicio `postgres` con ACL solo para ella y administradores
(sin lectura para usuarios de app ni el grupo de desarrollo general); a nivel
motor, no exponerlo por SQL salvo a `admin_datos`, con rotación y retención
definidas y copias con el mismo resguardo que la base.
