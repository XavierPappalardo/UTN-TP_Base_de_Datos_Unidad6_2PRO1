# spec: vista_01_productos_categoria

Objetivo: reporte "productos vigentes con su categoría" (simplificación).
Columnas a exponer: p.id_producto, p.nombre_producto, p.precio_producto,
p.stock_producto, c.nombre_categoria.
Filtro de vigencia: p.eliminado = FALSE AND c.eliminado = FALSE.
Seguridad: ninguna columna sensible (precios y stock son visibles para gestión).
Criterio de aceptación: SELECT * FROM v_reporte_productos_categorias devuelve
exactamente las mismas filas que la consulta manual (verificación con EXCEPT
en ambas direcciones, 0 filas de diferencia).
