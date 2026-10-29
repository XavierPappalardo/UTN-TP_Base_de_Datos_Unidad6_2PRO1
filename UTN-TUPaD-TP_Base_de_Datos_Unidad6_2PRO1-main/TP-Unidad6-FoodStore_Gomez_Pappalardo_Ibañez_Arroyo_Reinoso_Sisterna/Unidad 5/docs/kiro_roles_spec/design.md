# Diseño de roles y permisos — Food Store (Kiro: design)

> Formato Kiro (design). Complementa a `requirements.md`. Todo lo aquí
> diseñado se implementa en `sql/roles.sql`.

## 1. Mapa de herencia

```text
rol_app_lectura ──heredado por──> rol_app_escritura ──otorgado a──> app_web
rol_soporte            (login, app)
rol_reportes           (solo SELECT, sin secretos)
rol_auditor            (solo SELECT amplio, sin secretos, sin escritura)
admin_datos            (login admin funcional, CREATEROLE, sin SUPERUSER)
```

`rol_app_escritura` es miembro de `rol_app_lectura` (`GRANT rol_app_lectura TO
rol_app_escritura`), de modo que la escritura **suma** a la lectura sin
duplicar grants. `app_web` es miembro solo de `rol_app_escritura` (hereda la
lectura en cascada). `admin_datos` **no** hereda roles de app: sus permisos son
explícitos `ALL` para que una revocación en un rol de app nunca degrade la
administración.

## 2. Matriz de privilegios (tablas)

| Tabla / columnas | lectura | escritura | soporte | reportes | auditor | admin_datos |
|---|---|---|---|---|---|---|
| `categoria`, `producto`, `pedido`, `detalle_pedido` | SELECT | SELECT + INSERT/UPDATE (*ámbito abajo*) | SELECT | SELECT | SELECT | ALL |
| `usuario` (columnas no sensibles: `id_usuario, nombre_usuario, apellido_usuario, rol, eliminado, created_at` + `mail_usuario` solo donde se indica) | SELECT columnas sin `mail/celular/contrasena` | igual que lectura | SELECT + `mail_usuario, celular_usuario` (para contactar al cliente), **sin** `contrasena_usuario` | SELECT sin `mail/celular/contrasena` | SELECT sin `mail/celular/contrasena` | ALL |
| `producto.stock_producto` | — | UPDATE (solo esa columna) | — | — | — | ALL |
| `pedido.estado_pedido` | — | UPDATE (solo esa columna, más INSERT en `pedido/detalle_pedido`) | UPDATE (solo esa columna) | — | — | ALL |
| `detalle_pedido(cantidad, precio, subtotal)` | — | INSERT + UPDATE | — | — | — | ALL |
| `DELETE` en cualquier tabla | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (solo correcciones) |
| Secuencias (`USAGE, SELECT`) | ❌ | ✅ (necesario para INSERT con identity) | ❌ | ❌ | ❌ | ✅ |
| Esquema `public` (`USAGE`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CONNECT` a `food_store` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Ámbito de escritura de `rol_app_escritura`: `INSERT` en `pedido, detalle_pedido`;
`UPDATE` solo en `pedido(estado_pedido, total_pedido)` y
`producto(stock_producto)`. Sin `TRUNCATE, REFERENCES` innecesarios; sin
`DELETE`.

## 3. Vistas y funciones

- Vistas `v_categorias_vigentes, v_productos_vigentes, v_pedidos_resumen,
  v_pedido_detalle`: `SELECT` a los 5 roles de grupo (las vistas ya excluyen
  `eliminado = TRUE` y no exponen `contrasena_usuario`).
- `sp_crear_pedido, calcular_total_pedido, fn_autenticar`: `EXECUTE` a
  `rol_app_escritura` (y `fn_autenticar` también a `lectura` y `soporte`).
- `fn_resetear_password`: `EXECUTE` solo a `admin_datos`.
- `fn_soft_delete, fn_set_subtotal, fn_recalcular_total` (triggers internos):
  sin `GRANT` a roles de app (las ejecuta el dueño).

## 4. `fn_autenticar` / `fn_resetear_password` (reconstrucción Clase 2)

No existían en el repo clonado (verificado por búsqueda 2026-10-15), por lo
que se reconstruyen en `roles.sql` §0 como paso previo, con constancia en
bitácora:

```sql
fn_autenticar(p_mail TEXT, p_pass TEXT) RETURNS BOOLEAN
  -- SECURITY DEFINER, compara contrasena_usuario = p_pass (hash simple en
  -- desarrollo; en producción sería crypt() de pgcrypto). No revela si el
  -- mail existe: devuelve FALSE en ambos casos de fallo.
fn_resetear_password(p_mail TEXT, p_nuevo_hash TEXT) RETURNS VOID
  -- SECURITY DEFINER, UPDATE de contrasena_usuario; EXECUTE solo admin_datos.
```

`SECURITY DEFINER` + `REVOKE ALL ... FROM PUBLIC` + `GRANT EXECUTE` puntual es
el mecanismo que permite autenticar **sin** otorgar `SELECT` sobre secretos.

## 5. `ALTER DEFAULT PRIVILEGES` (tablas futuras)

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_app_lectura, rol_soporte, rol_reportes, rol_auditor;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO rol_app_lectura, rol_app_escritura;
```

Más `REVOKE CREATE ON SCHEMA public FROM PUBLIC` para que nadie salvo
`admin_datos/postgres` cree objetos.

## 6. Verificación

1. `psql -c "\du"` — membresías y atributos.
2. Consulta sobre `information_schema.role_table_grants` por rol y tabla
   (adjunta en `docs/verificacion_roles.txt`).
3. Pruebas negativas: login fallido, `SELECT` de columna prohibida, `INSERT` de
   reportes, `GRANT admin_datos` desde `app_web` — todos deben fallar con
   `permission denied` / `must be member of role`.
4. Tabla de prueba futura (`_verif_futura`) confirma herencia de defaults;
   se elimina al final.

## 7. Decisión explícita anti-`GRANT ALL`

Durante la revisión con IA se rechazó `GRANT ALL ON ALL TABLES TO
rol_app_escritura` (y equivalentes para reportes): otorgaba `DELETE, TRUNCATE,
REFERENCES` y lectura de secretos, violando REQ-03/REQ-05. Se mantuvo el grant
por columnas y por verbos. Detalle en `BITACORA.md`.
