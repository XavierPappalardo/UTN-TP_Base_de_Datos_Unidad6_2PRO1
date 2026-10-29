-- TP4 - Semana 4 - Parte 1
-- Consultas analiticas elegidas de queries.sql (cruzan 3+ tablas)
-- Requiere base food_store en PostgreSQL. Ejecutar con EXPLAIN (ANALYZE, BUFFERS).

-- Q1 = "Consultas analiticas adicionales" B de queries.sql
--     Facturacion por categoria y por mes (cruza detalle_pedido, pedido, producto, categoria)
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre_categoria AS categoria,
       date_trunc('month', ped.fecha_pedido) AS mes,
       SUM(dp.subtotal_detallepedido) AS facturado
FROM   detalle_pedido dp
JOIN   pedido   ped ON ped.id_pedido = dp.pedido_id AND ped.eliminado = FALSE
JOIN   producto pr  ON pr.id_producto = dp.producto_id
JOIN   categoria c  ON c.id_categoria = pr.categoria_id
WHERE  dp.eliminado = FALSE
GROUP  BY c.nombre_categoria, date_trunc('month', ped.fecha_pedido)
ORDER  BY mes, facturado DESC;

-- Q2 = "Consultas analiticas adicionales" C de queries.sql (versión que cruza 3 tablas)
--     Ranking de usuarios por gasto: usuario -> pedido -> detalle_pedido
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.id_usuario AS id,
       u.nombre_usuario || ' ' || u.apellido_usuario AS usuario,
       SUM(dp.subtotal_detallepedido) AS gasto,
       RANK() OVER (ORDER BY SUM(dp.subtotal_detallepedido) DESC) AS puesto
FROM   usuario u
JOIN   pedido ped ON ped.usuario_id = u.id_usuario AND ped.eliminado = FALSE
JOIN   detalle_pedido dp ON dp.pedido_id = ped.id_pedido AND dp.eliminado = FALSE
WHERE  u.eliminado = FALSE
GROUP  BY u.id_usuario, u.nombre_usuario, u.apellido_usuario
ORDER  BY puesto;