# Especificación de roles — Food Store (Kiro: requirements)

> Redactado en formato Kiro (requirements) antes de escribir `roles.sql`.
> Asistido por IA, revisado y aprobado por el equipo Grupo E.
> Fecha: 2026-10-15. Base: Food Store Unidades 1–4 (PostgreSQL 16, tablas
> `categoria, producto, usuario, pedido, detalle_pedido` + vistas y rutinas de `objects.sql`).

## Contexto

Food Store necesita un esquema de identidades que aplique el **principio de
mínimo privilegio**: cada rol recibe exactamente los permisos que su operación
requiere, y ninguno más. Esta especificación justifica cada rol en una oración
antes de otorgar ningún `GRANT` (planificar antes de otorgar).

## Requisitos

### REQ-01 — Roles de grupo (NOLOGIN, sin password)

| Rol | Justificación (una oración) |
|-----|------------------------------|
| `rol_app_lectura` | Habilita a la app web a **leer** catálogo, pedidos y datos no sensibles de usuarios, porque el storefront debe mostrar productos y estado de compra sin ver credenciales. |
| `rol_app_escritura` | Habilita a la app web a **crear pedidos y descontar stock** vía `sp_crear_pedido`, porque el checkout necesita insertar en `pedido/detalle_pedido` sin poder borrar ni administrar usuarios. |
| `rol_soporte` | Habilita a mesa de ayuda a **ver pedidos/usuarios no sensibles y cambiar `estado_pedido`**, porque debe resolver reclamos y cancelaciones sin crear pedidos ni ver contraseñas. |
| `rol_reportes` | Habilita a BI a **leer vistas y tablas para reportes**, porque necesita agregados de ventas sin modificar datos ni ver credenciales o celulares. |
| `rol_auditor` (adicional del equipo) | Habilita a auditoría interna a **leer todo en modo solo-lectura para rendir cuentas**, porque debe verificar permisos y datos sin poder modificar nada ni ver secretos. |

### REQ-02 — Roles de login (con password, CONNECTION LIMIT)

| Rol | Justificación (una oración) |
|-----|------------------------------|
| `app_web` | Identidad con la que **corre la aplicación web** (miembro de `rol_app_escritura`, que a su vez hereda lectura), porque concentra todo el tráfico de clientes en una sola credencial revocable. |
| `admin_datos` | Identidad de **administración funcional** (CREATEROLE, sin SUPERUSER) con acceso total sobre Food Store, porque alguien debe crear roles, corregir datos y rotar secretos sin usar el superusuario `postgres`. |

> **Ampliación del equipo (permitida por la consigna):** además de los 2
> logins mínimos se crean 3 usuarios de prueba — `usr_lectura` (miembro de
> `rol_app_lectura`), `usr_soporte` (de `rol_soporte`) y `usr_reportes` (de
> `rol_reportes`) — exclusivamente para ejecutar la verificación de permisos
> y el simulacro de incidente con el privilegio real de cada grupo, sin usar
> nunca el superusuario para probar.

### REQ-03 — Permiso a nivel de columna (obligatorio)

Ningún rol de aplicación/reportes/soporte/auditoría puede leer
`usuario.contrasena_usuario` (ni `celular_usuario` salvo soporte parcial).
Se otorga `SELECT` **por columnas explícitas** sobre `usuario`, excluyendo
secretos; solo `admin_datos` (y el dueño `postgres`) ven la tabla completa.
La autenticación se hace vía `fn_autenticar` con `SECURITY DEFINER`, no por
lectura directa.

### REQ-04 — Tablas futuras heredan la política

Toda tabla/vista/función/secuencia creada a futuro en `public` por `postgres`
o por `admin_datos` debe otorgar automáticamente los mismos `SELECT` de
lectura (y nada de escritura salvo a `rol_app_escritura` en su ámbito), vía
`ALTER DEFAULT PRIVILEGES`. No se acepta que un `CREATE TABLE` quede
accidentalmente legible por `PUBLIC` o escribible por reportes.

### REQ-05 — Borrado físico prohibido para la app

Ningún rol de aplicación posee `DELETE` sobre ninguna tabla (el borrado es
lógico vía `eliminado = TRUE`, coherente con `fn_soft_delete`); solo
`admin_datos` conserva `DELETE` para correcciones excepcionales.

### REQ-06 — Funciones sensibles

- `fn_autenticar(mail, pass)` es `SECURITY DEFINER` y ejecutable por
  `rol_app_lectura, rol_app_escritura, rol_soporte` (la app debe validar login
  sin leer hashes).
- `fn_resetear_password(mail, nuevo_hash)` es `SECURITY DEFINER` y ejecutable
  **solo** por `admin_datos` (rotar credenciales es operación reservada).
- `sp_crear_pedido` y `calcular_total_pedido` son ejecutables por
  `rol_app_escritura` (checkout) y lectura por reportes donde aplique.

## Criterios de aceptación

1. `\du` muestra los 5 roles de grupo (NOLOGIN) y los 2 login, con las
   membresías previstas y sin SUPERUSER salvo `postgres`.
2. `information_schema.role_table_grants` confirma, tabla por tabla, que cada
   rol tiene exactamente lo especificado (ni más, ni menos).
3. Un miembro de `rol_app_lectura` **falla** al hacer
   `SELECT contrasena_usuario FROM usuario` y al intentar `GRANT admin_datos`.
4. Un miembro de `rol_reportes` **falla** al intentar `INSERT/UPDATE/DELETE`.
5. Tablas creadas después de aplicar `ALTER DEFAULT PRIVILEGES` ya nacen con
   el `SELECT` de lectura otorgado (verificado con tabla de prueba).
