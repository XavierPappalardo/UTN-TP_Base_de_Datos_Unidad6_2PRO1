# spec: vista_materializada_facturacion

Objetivo: reporte agregado costoso "facturación por categoría y mes"
(queries.sql B: 4 JOINs + GROUP BY sobre ~10000 filas de detalle_pedido).
Definición: GROUP BY c.id_categoria, c.nombre_categoria,
date_trunc('month', ped.fecha_pedido); medida SUM(dp.subtotal_detallepedido).
Con WITH DATA para que nazca poblada.
Índice único: (id_categoria, mes) para permitir a futuro REFRESH CONCURRENTLY
(exigencia del TP: sin índice único el CONCURRENTLY es imposible).
Criterio de aceptación: (1) SELECT desde la MV es al menos un orden de magnitud
más rápido que la consulta original; (2) REFRESH CONCURRENTLY funciona;
(3) frecuencia de refresco justificada por escrito (ver informe §C3).
Uso esperado: lectura diaria del dashboard comercial; el dato puede tener
desfase de hasta 24 h (stale read documentado y aceptado).
