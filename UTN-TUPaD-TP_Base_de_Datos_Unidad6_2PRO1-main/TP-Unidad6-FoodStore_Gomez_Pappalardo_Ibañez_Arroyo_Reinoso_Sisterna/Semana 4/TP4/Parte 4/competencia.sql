-- TP4 - Parte 4 - Consulta comun de la competencia
-- Facturacion por usuario y categoria (>= 2 JOIN + agregacion), igual para todos los
-- equipos sobre la base compartida.
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.apellido_usuario || ', ' || u.nombre_usuario AS usuario,
       c.nombre_categoria,
       SUM(dp.subtotal_detallepedido) AS facturado
FROM   detalle_pedido dp
JOIN   pedido   ped ON ped.id_pedido = dp.pedido_id      AND ped.eliminado  = FALSE
JOIN   usuario  u   ON u.id_usuario = ped.usuario_id     AND u.eliminado    = FALSE
JOIN   producto pr  ON pr.id_producto = dp.producto_id
JOIN   categoria c  ON c.id_categoria = pr.categoria_id AND c.eliminado    = FALSE
WHERE  dp.eliminado = FALSE
GROUP  BY u.id_usuario, u.apellido_usuario, u.nombre_usuario,
          c.id_categoria, c.nombre_categoria
ORDER  BY facturado DESC;