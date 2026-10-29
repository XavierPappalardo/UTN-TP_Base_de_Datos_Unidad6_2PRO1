# BITÁCORA de uso de IA — TP Unidad 5, Food Store

Grupo E: Gómez, Pappalardo, Reinoso, Ibáñez, Sisterna, Arroyo · 2026-10-15

> Formato obligatorio: Prompt enviado a la IA | Respuesta relevante recibida
> (resumida) | Validación o corrección humana aplicada. Rol de IA de terminal
> (OpenCode) cumplido por el asistente de IA de esta sesión, con validación
> humana/ejecución real en cada paso. Repositorio base reconstruido como paso
> previo (constancia abajo): el repo clonado no contenía `roles.sql` ni
> `fn_autenticar`/`fn_resetear_password` (búsqueda exhaustiva 2026-10-15).

| Parte | Prompt enviado a la IA | Respuesta relevante (resumen) | Validación / corrección humana |
|---|---|---|---|
| Previa | "Cloná el repo y fijate si tiene errores" | Clon detectó `Filename too long` en Windows (3 PDF con rutas >260); propuso `git -c core.longpaths=true` + clonado en ruta corta | ✅ Verificado: 2.º clon íntegro; causa documentada (MAX_PATH Windows, no corrupción del repo). Archivos SQL base (Unidades 1–4) intactos |
| Previa | "¿Existe roles.sql / fn_autenticar / usuario_anon en el repo?" | Búsqueda en todo el árbol: no existe ninguno | ✅ Reconstrucción como paso previo (S0-bis/S4 de `roles.sql`), con constancia aquí y en `design.md` §4 |
| A | "Diseñame roles con mínimo privilegio para estas 5 tablas + spec Kiro" | Propuso esquema + borrador con `GRANT EXECUTE ON FUNCTION sp_crear_pedido(...)` y limpieza con `DROP ROLE IF EXISTS` simple | ⚠️ Corrección 1: `sp_crear_pedido` es PROCEDURE → `ERROR no es una función`; cambiado a `ON PROCEDURE`. Corrección 2: el DROP simple falla en 2.ª corrida (dependencias en grants, default-privs y procedures) → limpieza en 3 fases |
| A | "Auditá roles.sql y proponé mejoras" (auditoría obligatoria punto 4) | La IA propuso **simplificar con `GRANT ALL ON ALL TABLES TO rol_app_escritura`** (y `EXECUTE ON ALL FUNCTIONS` a todos) | ❌ **Rechazado por inseguro/de más:** otorgaba `DELETE/TRUNCATE` (viola borrado lógico REQ-05) y `EXECUTE` sobre `fn_resetear_password` a la app. Se mantuvo grant por columnas/verbos y por rutina. Detectado al cruzar cada grant con REQ-03/REQ-05; pruebas negativas (`permiso denegado` ×3) lo confirman. Ver `design.md` §7 |
| A | "Hacé idempotente el DROP con DELETE a pg_default_acl" (idea de la IA) | La IA generó el `DELETE FROM pg_default_acl` como atajo | ❌ **Caso más significativo (punto 2, abajo).** Manipulación directa de catálogo: corrompió `pg_shdepend` (`XX000 could not find tuple for default ACL`), dejando 6 roles ineliminables. Se detectó en la 2.ª corrida y se corrigió recreando `food_store` desde `SQL/{schema,objects,data}.sql` + limpieza en 3 fases sin tocar catálogos. Doble corrida limpia posterior = prueba |
| B | "¿Qué parámetros activo para auditoría y cómo sin reiniciar?" | `log_connections/on, log_disconnections/on, log_statement='mod', log_line_prefix` con usuario/host + `ALTER SYSTEM` + `pg_reload_conf()` | ✅ Verificado con `SHOW`: el reload bastó (sin restart); fragmento real capturado en `log_auditoria_prueba.txt`. Corrección menor: la IA primero sugirió `log_statement='all'` permanente; se dejó `'mod'` (mínimo que registra modificación) y `'all'` solo temporal y acotado a la base en la Parte C |
| C | Solo el log anonimizado + "reconstruí qué ocurrió, sin más contexto" | Reconstrucción + hipótesis de contención (texto completo en `informe_incidente.md` §2) | ⚠️ Lectura crítica (§3): 3 afirmaciones sin sustento en el log (cuál intento tuvo éxito, volumen exfiltrado, atribución de ataque) + 2 omisiones. Decisión de contención tomada por el equipo (§4), no ejecutada automáticamente |
| D | "Dada esta agregación sobre usuario_anon, dame la equivalente sobre usuario" | `GROUP BY rol, mes` idéntica cambiando solo la tabla | ✅ Ejecutadas ambas: ADMIN 1 / USUARIO 4 en las dos. Equivalencia demostrada. Límite detectado por el equipo: no vale para búsquedas por nombre (documentado en `verificacion_equivalencia.md`) |

## Caso más significativo de error de la IA (Parte E, punto 2)

El `DELETE FROM pg_default_acl` propuesto por la IA como "atajo" para hacer
`roles.sql` idempotente. Parecía razonable (corre como superusuario, una sola
línea) y pasó la primera ejecución sin síntomas. Se detectó en la **segunda**
corrida consecutiva: `DROP ROLE` empezó a fallar con `XX000 could not find
tuple for default ACL`, un error interno que delataba dependencias huérfanas
en `pg_shdepend`. El diagnóstico (bloque DO con `RAISE NOTICE` de
`SQLSTATE/SQLERRM` por cada DROP) confirmó que 6 roles habían quedado
ineliminables. La corrección fue recrear `food_store` desde los scripts base
del repo y reescribir la limpieza en 3 fases ordenadas (objetos → defaults →
drops) sin tocar catálogos del sistema, verificada con dos corridas limpias
seguidas. Lección: ningún atajo contra catálogos del sistema en scripts
entregables; la idempotencia se prueba corriendo dos veces, no una.

## Historial Git (Parte E, punto 3)

```text
* BITÁCORA + cierre (este commit)
* TP-U5 Parte D: usuario_anon determinista y equivalencia agregada verificada
* TP-U5 Parte C: simulacro de incidente, log anonimizado e informe con lectura critica
* TP-U5 Parte B: auditoria activada, secuencia de prueba y fragmento de log real
* TP-U5 Parte A: spec Kiro de roles, roles.sql verificado e idempotente
```

Un commit por parte, mensajes que dicen qué y por qué. Si algo haríamos
distinto: commitear el `ALTER DATABASE ... SET log_statement='all'` temporal
de la Parte C como paso explícito del script en vez de comando suelto de
shell (quedó documentado en el informe, pero no como artefacto versionado).
