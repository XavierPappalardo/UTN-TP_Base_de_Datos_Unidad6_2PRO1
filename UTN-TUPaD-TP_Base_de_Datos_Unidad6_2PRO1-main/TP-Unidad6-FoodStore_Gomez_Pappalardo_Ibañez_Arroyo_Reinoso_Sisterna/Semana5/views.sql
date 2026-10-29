-- views.sql — Partes B (vistas) y C (vista materializada). Unidad 3, Semana 5.
-- Cada vista proviene de un spec en specs/ y fue verificada por equivalencia
-- contra su consulta manual con EXCEPT (ver informe_mediciones.md §B y §C).
-- Nombres nuevos v_reporte_*/v_seguridad_*/mv_* para no colisionar con objects.sql
-- heredado (v_productos_vigentes, v_pedidos_resumen, v_pedido_detalle).

-- B1 — Productos vigentes con su categoría.
-- Spec: specs/spec_vista_01_productos_categoria.md
CREATE OR REPLACE VIEW v_reporte_productos_categorias AS
SELECT p.id_producto,
       p.nombre_producto,
       p.precio_producto,
       p.stock_producto,
       c.nombre_categoria
FROM producto p
JOIN categoria c ON p.categoria_id = c.id_categoria
WHERE p.eliminado = FALSE
  AND c.eliminado = FALSE;

-- B2 — Pedidos con datos del usuario, CON CRITERIO DE SEGURIDAD.
-- Spec: specs/spec_vista_02_pedidos_usuarios_segura.md
-- Oculta explícitamente contrasena_usuario (y celular): se puede otorgar
-- SELECT sobre la vista sin dar acceso a la tabla base usuario.
CREATE OR REPLACE VIEW v_seguridad_pedidos_usuarios AS
SELECT ped.id_pedido,
       ped.fecha_pedido,
       ped.estado_pedido,
       ped.total_pedido,
       ped.forma_pago,
       u.id_usuario,
       u.nombre_usuario,
       u.apellido_usuario,
       u.mail_usuario
FROM pedido ped
JOIN usuario u ON ped.usuario_id = u.id_usuario
WHERE ped.eliminado = FALSE
  AND u.eliminado = FALSE;

-- B3 — Detalle de pedido con nombre del producto.
-- Spec: specs/spec_vista_03_detalle_producto.md
CREATE OR REPLACE VIEW v_reporte_detalle_pedido_producto AS
SELECT dp.pedido_id,
       p.nombre_producto,
       dp.cantidad_detallepedido,
       dp.precio_unitario,
       dp.subtotal_detallepedido
FROM detalle_pedido dp
JOIN producto p ON dp.producto_id = p.id_producto
WHERE dp.eliminado = FALSE
  AND p.eliminado = FALSE;

-- C — Vista materializada: facturación por categoría y mes (reporte agregado costoso,
-- queries.sql B con GROUP BY + 4 JOINs sobre ~10000 filas).
-- Spec: specs/spec_vista_materializada_facturacion.md
DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;

CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT c.id_categoria,
       c.nombre_categoria,
       date_trunc('month', ped.fecha_pedido) AS mes,
       SUM(dp.subtotal_detallepedido) AS facturacion_total
FROM detalle_pedido dp
JOIN pedido ped   ON dp.pedido_id = ped.id_pedido
JOIN producto pr  ON dp.producto_id = pr.id_producto
JOIN categoria c  ON pr.categoria_id = c.id_categoria
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre_categoria, date_trunc('month', ped.fecha_pedido)
WITH DATA;

-- Índice único obligatorio para permitir REFRESH CONCURRENTLY a futuro.
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_facturacion_unico
    ON mv_facturacion_categoria_mes (id_categoria, mes);

-- Refresco recomendado (ver informe §C3): REFRESH MATERIALIZED VIEW CONCURRENTLY
-- mv_facturacion_categoria_mes; frecuencia diaria nocturna o tras cierre de caja.
