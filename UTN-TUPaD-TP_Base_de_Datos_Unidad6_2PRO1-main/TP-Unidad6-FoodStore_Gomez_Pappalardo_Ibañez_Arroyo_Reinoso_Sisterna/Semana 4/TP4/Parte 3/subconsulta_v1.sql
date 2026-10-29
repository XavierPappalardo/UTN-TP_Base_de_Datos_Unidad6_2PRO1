-- TP4 - Parte 3 (b) - Productos que venden por encima del promedio de su categoria
-- v1 (subconsulta correlacionada, CORREGIDA)
--
-- Spec: "Genera una consulta SQL sobre el esquema de Food Store que devuelva los
--  productos vigentes cuya recaudacion total (suma de subtotal de detalles no
--  eliminados, dentro de pedidos no eliminados) supera el promedio de recaudacion de
--  los productos de su misma categoria. Incluir nombre del producto, categoria y
--  recaudacion. No uses SELECT *."
--
-- NOTA: la primer version agrupaba el subquery por categoria_id (recau = TOTAL de la
-- categoria) y comparaba el producto contra ese total, no contra el promedio por
-- producto. La verificacion con EXCEPT la detecto (v1=0 filas vs v2=2 filas). Corregida
-- agregando id_producto al GROUP BY del subquery. Documentado en resultados_equivalencia.md.
SELECT pr.id_producto,
       pr.nombre_producto,
       c.nombre_categoria,
       SUM(dp.subtotal_detallepedido) AS recaudacion
FROM   detalle_pedido dp
JOIN   pedido   ped ON ped.id_pedido = dp.pedido_id AND ped.eliminado = FALSE
JOIN   producto pr  ON pr.id_producto = dp.producto_id AND pr.eliminado = FALSE
JOIN   categoria c  ON c.id_categoria = pr.categoria_id AND c.eliminado = FALSE
WHERE  dp.eliminado = FALSE
GROUP  BY pr.id_producto, pr.nombre_producto, c.nombre_categoria, pr.categoria_id
HAVING SUM(dp.subtotal_detallepedido) > (
    SELECT AVG(pc.recaudacion)
    FROM (
        SELECT pr2.categoria_id,
               pr2.id_producto,
               SUM(dp2.subtotal_detallepedido) AS recaudacion
        FROM   detalle_pedido dp2
        JOIN   pedido   ped2 ON ped2.id_pedido = dp2.pedido_id AND ped2.eliminado = FALSE
        JOIN   producto pr2  ON pr2.id_producto = dp2.producto_id AND pr2.eliminado = FALSE
        JOIN   categoria c2  ON c2.id_categoria = pr2.categoria_id AND c2.eliminado = FALSE
        WHERE  dp2.eliminado = FALSE
        GROUP  BY pr2.categoria_id, pr2.id_producto
    ) pc
    WHERE pc.categoria_id = pr.categoria_id
);