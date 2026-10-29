# spec: indice_pedido_fecha_estado

Objetivo: acelerar el reporte "pedidos confirmados de un mes".

Consulta afectada:
SELECT id_pedido, fecha_pedido, total_pedido FROM pedido
 WHERE fecha_pedido BETWEEN :desde AND :hasta
   AND estado_pedido = 'CONFIRMADO' AND eliminado = FALSE;

Frecuencia: alta (reporte mensual de caja, varias veces por día en cierre).
Columnas candidatas: estado_pedido (igualdad, baja selectividad),
fecha_pedido (rango, alta selectividad), eliminado (borrado lógico).
Tipo propuesto: B-tree compuesto (estado_pedido, fecha_pedido) parcial
WHERE eliminado = FALSE. Igualdad primero, rango después.
Criterio de aceptación: el plan pasa de Seq Scan a Index/Bitmap Scan
y el tiempo baja al menos un orden de magnitud con volumen (~5000 pedidos).
