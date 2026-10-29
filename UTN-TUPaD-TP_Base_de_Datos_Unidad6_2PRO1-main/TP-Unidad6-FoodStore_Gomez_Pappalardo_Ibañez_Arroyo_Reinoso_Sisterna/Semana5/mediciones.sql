-- mediciones.sql — protocolo reproducible de medición (Unidad 3, Semana 5).
-- Ejecutar en PostgreSQL 16+ DESPUÉS de schema.sql -> objects.sql (heredado Semana 4)
-- -> data.sql (este repo, con volumen) y ANTES de indices.sql / views.sql para el "antes".
-- Luego ejecutar indices.sql + views.sql y repetir cada bloque para el "después".
-- Copiar cada salida de EXPLAIN (ANALYZE, BUFFERS) a informe_mediciones.md.

-- 0) Precondición: volumen y estadísticas.
-- SELECT count(*) FROM pedido WHERE eliminado = FALSE;          -- esperado 5004
-- SELECT count(*) FROM detalle_pedido WHERE eliminado = FALSE;  -- esperado 10007
-- SELECT count(*) FROM producto WHERE eliminado = FALSE;        -- esperado 2014
-- VACUUM (ANALYZE) pedido; VACUUM (ANALYZE) detalle_pedido; VACUUM (ANALYZE) producto;

-- A1) Q1 — pedidos confirmados de un mes.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha_pedido, total_pedido FROM pedido
 WHERE fecha_pedido BETWEEN '2025-09-17' AND '2026-09-17'
   AND estado_pedido = 'CONFIRMADO' AND eliminado = FALSE;

-- A2) Q2 — Top 5 productos más vendidos.
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto AS id, pr.nombre_producto AS nombre,
       SUM(dp.cantidad_detallepedido) AS unidades
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.eliminado = FALSE
GROUP BY pr.id_producto, pr.nombre_producto
ORDER BY unidades DESC LIMIT 5;

-- A2b) Q2 complementaria — ventas de un producto (770 filas, selectiva).
-- El Top 5 total no cambia de plan (agrega las 10007 filas igual); esta consulta
-- demuestra el uso real de idx_detalle_producto.
EXPLAIN (ANALYZE, BUFFERS)
SELECT dp.pedido_id, dp.cantidad_detallepedido, dp.subtotal_detallepedido
FROM detalle_pedido dp
WHERE dp.producto_id = 4 AND dp.eliminado = FALSE ORDER BY dp.pedido_id;

-- A3) Q3 — productos de una categoría ordenados por precio (2003 filas en cat. 1
-- gracias al volumen de data.sql §2.4; sin ese volumen el planificador usa Seq Scan).
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre_producto, precio_producto, stock_producto FROM producto
 WHERE categoria_id = 1 AND eliminado = FALSE ORDER BY precio_producto ASC;

-- A4) Costo en escritura: 500 INSERT en detalle_pedido (medir con \timing en psql).
-- Ejecutar ANTES y DESPUÉS de indices.sql y anotar ambos tiempos.
-- \timing on
-- INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id)
-- SELECT 1, pr.precio_producto, pr.precio_producto, p.id_pedido, pr.id_producto
-- FROM (SELECT id_pedido FROM pedido WHERE eliminado = FALSE ORDER BY id_pedido LIMIT 500) p
-- CROSS JOIN LATERAL (SELECT precio_producto, (((p.id_pedido + 7) % 13) + 1) AS pid) s
-- JOIN producto pr ON pr.id_producto = s.pid;
-- -- Deshacer la prueba para no contaminar mediciones: ROLLBACK si se envolvió en transacción.

-- B) Equivalencia de vistas (debe devolver 0 filas en las 6 consultas).
-- B1
-- (SELECT p.id_producto, p.nombre_producto, p.precio_producto, p.stock_producto, c.nombre_categoria
--  FROM producto p JOIN categoria c ON p.categoria_id = c.id_categoria
--  WHERE p.eliminado = FALSE AND c.eliminado = FALSE
--  EXCEPT SELECT * FROM v_reporte_productos_categorias)
-- UNION ALL
-- (SELECT * FROM v_reporte_productos_categorias
--  EXCEPT SELECT p.id_producto, p.nombre_producto, p.precio_producto, p.stock_producto, c.nombre_categoria
--  FROM producto p JOIN categoria c ON p.categoria_id = c.id_categoria
--  WHERE p.eliminado = FALSE AND c.eliminado = FALSE);
-- B2
-- (SELECT ped.id_pedido, ped.fecha_pedido, ped.estado_pedido, ped.total_pedido, ped.forma_pago,
--         u.id_usuario, u.nombre_usuario, u.apellido_usuario, u.mail_usuario
--  FROM pedido ped JOIN usuario u ON ped.usuario_id = u.id_usuario
--  WHERE ped.eliminado = FALSE AND u.eliminado = FALSE
--  EXCEPT SELECT * FROM v_seguridad_pedidos_usuarios)
-- UNION ALL
-- (SELECT * FROM v_seguridad_pedidos_usuarios
--  EXCEPT SELECT ped.id_pedido, ped.fecha_pedido, ped.estado_pedido, ped.total_pedido, ped.forma_pago,
--         u.id_usuario, u.nombre_usuario, u.apellido_usuario, u.mail_usuario
--  FROM pedido ped JOIN usuario u ON ped.usuario_id = u.id_usuario
--  WHERE ped.eliminado = FALSE AND u.eliminado = FALSE);
-- B3
-- (SELECT dp.pedido_id, p.nombre_producto, dp.cantidad_detallepedido, dp.precio_unitario, dp.subtotal_detallepedido
--  FROM detalle_pedido dp JOIN producto p ON dp.producto_id = p.id_producto
--  WHERE dp.eliminado = FALSE AND p.eliminado = FALSE
--  EXCEPT SELECT * FROM v_reporte_detalle_pedido_producto)
-- UNION ALL
-- (SELECT * FROM v_reporte_detalle_pedido_producto
--  EXCEPT SELECT dp.pedido_id, p.nombre_producto, dp.cantidad_detallepedido, dp.precio_unitario, dp.subtotal_detallepedido
--  FROM detalle_pedido dp JOIN producto p ON dp.producto_id = p.id_producto
--  WHERE dp.eliminado = FALSE AND p.eliminado = FALSE);
-- Seguridad B2: verificar que la contraseña NO está expuesta:
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'v_seguridad_pedidos_usuarios';  -- no debe listar contrasena_usuario

-- C) Vista materializada vs consulta original.
-- \timing on
-- Consulta original:
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre_categoria AS categoria, date_trunc('month', ped.fecha_pedido) AS mes,
       SUM(dp.subtotal_detallepedido) AS facturado
FROM detalle_pedido dp
JOIN pedido ped ON ped.id_pedido = dp.pedido_id AND ped.eliminado = FALSE
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.categoria_id
WHERE dp.eliminado = FALSE
GROUP BY c.nombre_categoria, date_trunc('month', ped.fecha_pedido)
ORDER BY mes, facturado DESC;
-- Contra la MV:
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes, facturacion_total DESC;
-- Refresh concurrente (requiere el índice único):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
