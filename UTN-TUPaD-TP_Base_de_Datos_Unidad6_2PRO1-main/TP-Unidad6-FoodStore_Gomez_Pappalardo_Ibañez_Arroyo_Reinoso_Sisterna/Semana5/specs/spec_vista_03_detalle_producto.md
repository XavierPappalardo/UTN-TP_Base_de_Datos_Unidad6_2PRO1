# spec: vista_03_detalle_producto

Objetivo: reporte "detalle de un pedido con el nombre del producto".
Columnas a exponer: dp.pedido_id, p.nombre_producto, dp.cantidad_detallepedido,
dp.precio_unitario, dp.subtotal_detallepedido.
Filtro de vigencia: dp.eliminado = FALSE AND p.eliminado = FALSE.
Seguridad: sin columnas sensibles.
Criterio de aceptación: equivalencia exacta con la consulta manual (EXCEPT
bidireccional, 0 filas) antes de dar la vista por válida.
