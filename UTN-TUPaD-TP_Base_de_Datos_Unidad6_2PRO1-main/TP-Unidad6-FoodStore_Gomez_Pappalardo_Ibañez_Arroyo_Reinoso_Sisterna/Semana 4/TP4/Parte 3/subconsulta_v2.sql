-- TP4 - Parte 3 (b) - Productos que venden por encima del promedio de su categoria
-- v2 (estructura distinta: funciones de ventana, sin subconsulta correlacionada)
WITH recau_producto AS (
    SELECT pr.id_producto,
           pr.categoria_id,
           SUM(dp.subtotal_detallepedido) AS recaudacion
    FROM   detalle_pedido dp
    JOIN   pedido   ped ON ped.id_pedido = dp.pedido_id AND ped.eliminado = FALSE
    JOIN   producto pr  ON pr.id_producto = dp.producto_id AND pr.eliminado = FALSE
    WHERE  dp.eliminado = FALSE
    GROUP  BY pr.id_producto, pr.categoria_id
),
con_promedio AS (
    SELECT rp.id_producto,
           rp.categoria_id,
           rp.recaudacion,
           AVG(rp.recaudacion) OVER (PARTITION BY rp.categoria_id) AS promedio_categoria
    FROM   recau_producto rp
)
SELECT cp.id_producto,
       pr.nombre_producto,
       c.nombre_categoria,
       cp.recaudacion
FROM   con_promedio cp
JOIN   producto pr ON pr.id_producto = cp.id_producto
JOIN   categoria c ON c.id_categoria = cp.categoria_id
WHERE  cp.recaudacion > cp.promedio_categoria;