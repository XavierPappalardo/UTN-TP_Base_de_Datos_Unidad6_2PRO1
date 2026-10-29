# spec: indice_detalle_producto

Objetivo: acelerar JOINs y agregados por producto (Top 5 más vendidos,
facturación por categoría y mes).

Consultas afectadas:
SELECT pr.id_producto, SUM(dp.cantidad_detallepedido) ... FROM detalle_pedido dp
 JOIN producto pr ON pr.id_producto = dp.producto_id
 WHERE dp.eliminado = FALSE GROUP BY pr.id_producto ...;
-- y la consulta B de queries.sql (4 JOINs + GROUP BY con detalle_pedido como hecho).

Frecuencia: alta (dashboard de ventas y reportes analíticos diarios).
Columnas candidatas: detalle_pedido.producto_id (JOIN + GROUP BY).
Tipo propuesto: B-tree simple (producto_id) parcial WHERE eliminado = FALSE.
Criterio de aceptación: el plan sobre detalle_pedido pasa de Seq Scan a
Index/Bitmap Heap Scan y el tiempo de los agregados baja de forma observable.
