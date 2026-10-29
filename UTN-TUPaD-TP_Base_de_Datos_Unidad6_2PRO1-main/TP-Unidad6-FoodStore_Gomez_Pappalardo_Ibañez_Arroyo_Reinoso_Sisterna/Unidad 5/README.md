# Unidad 5 — TP (Food Store: administración y seguridad)

Grupo E: Gómez, Pappalardo, Reinoso, Ibáñez, Sisterna, Arroyo · 2026-10-15

## Contenido

Entregables del TP Unidad 5 (Partes A–E), según la estructura de la consigna:

- `sql/roles.sql`: esquema de roles y permisos de mínimo privilegio
  (incluye reconstrucción de `fn_autenticar` / `fn_resetear_password`).
- `sql/auditoria_test.sql`: secuencia de prueba de auditoría.
- `sql/simulacro_incidente.sql`: simulacro controlado (solo entorno propio).
- `sql/usuario_anon.sql`: tabla anonimizada determinista + agregados.
- `docs/`: spec Kiro, informes, fragmentos de log, verificaciones.
- `BITACORA.md`: bitácora de uso de IA.

## Orden de ejecución (PostgreSQL 16, como superusuario, `-d food_store`)

1. Base previa: `SQL/schema.sql` → `SQL/objects.sql` → `SQL/data.sql`
   (o la base ya poblada de Unidades 1–4).
2. `Unidad 5/sql/roles.sql` (idempotente; ejecutar **conectado a `food_store`**).
3. `Unidad 5/sql/auditoria_test.sql` (+ login fallido desde shell).
4. `Unidad 5/sql/simulacro_incidente.sql` (como `app_web`, solo desarrollo).
5. `Unidad 5/sql/usuario_anon.sql` (idempotente).
