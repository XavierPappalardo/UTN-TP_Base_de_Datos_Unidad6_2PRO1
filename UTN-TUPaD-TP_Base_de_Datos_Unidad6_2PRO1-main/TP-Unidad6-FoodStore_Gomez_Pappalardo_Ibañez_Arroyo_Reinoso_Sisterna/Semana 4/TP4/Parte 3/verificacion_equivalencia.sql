-- TP4 - Parte 3 - Verificacion formal de equivalencia (EXCEPT en ambos sentidos)
-- Debe dar 0 filas en ambos sentidos y conteos iguales si las versiones son equivalentes.

-- (a) Ranking v1 (funcion de ventana) vs v2 (subconsulta que cuenta competidores)
CREATE TEMP VIEW rk_v1 AS
SELECT u.id_usuario,
       u.nombre_usuario || ' ' || u.apellido_usuario AS nombre_completo,
       SUM(p.total_pedido) AS total_gastado,
       RANK() OVER (ORDER BY SUM(p.total_pedido) DESC) AS puesto
FROM   usuario u
JOIN   pedido p ON p.usuario_id = u.id_usuario AND p.eliminado = FALSE
WHERE  u.eliminado = FALSE
GROUP  BY u.id_usuario, u.nombre_usuario, u.apellido_usuario;

CREATE TEMP VIEW rk_v2 AS
WITH gasto_usuario AS (
    SELECT u.id_usuario,
           u.nombre_usuario || ' ' || u.apellido_usuario AS nombre_completo,
           SUM(p.total_pedido) AS total_gastado
    FROM   usuario u
    JOIN   pedido p ON p.usuario_id = u.id_usuario AND p.eliminado = FALSE
    WHERE  u.eliminado = FALSE
    GROUP  BY u.id_usuario, u.nombre_usuario, u.apellido_usuario
)
SELECT gu.id_usuario,
       gu.nombre_completo,
       gu.total_gastado,
       (SELECT COUNT(*) + 1
        FROM   gasto_usuario gg
        WHERE  gg.total_gastado > gu.total_gastado) AS puesto
FROM   gasto_usuario gu;

SELECT 'rank v1 EXCEPT v2' AS prueba, count(*) AS filas FROM ((TABLE rk_v1) EXCEPT (TABLE rk_v2)) t
UNION ALL
SELECT 'rank v2 EXCEPT v1', count(*) FROM ((TABLE rk_v2) EXCEPT (TABLE rk_v1)) t
UNION ALL
SELECT 'rank conteo v1', count(*) FROM rk_v1
UNION ALL
SELECT 'rank conteo v2', count(*) FROM rk_v2;

-- (b) Subconsulta correlacionada v1 (corregida) vs v2 (funciones de ventana)
CREATE TEMP VIEW sc_v1 AS
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

CREATE TEMP VIEW sc_v2 AS
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

SELECT 'sub v1 EXCEPT v2' AS prueba, count(*) AS filas FROM ((TABLE sc_v1) EXCEPT (TABLE sc_v2)) t
UNION ALL
SELECT 'sub v2 EXCEPT v1', count(*) FROM ((TABLE sc_v2) EXCEPT (TABLE sc_v1)) t
UNION ALL
SELECT 'sub conteo v1', count(*) FROM sc_v1
UNION ALL
SELECT 'sub conteo v2', count(*) FROM sc_v2;

DROP VIEW sc_v2, sc_v1, rk_v2, rk_v1;