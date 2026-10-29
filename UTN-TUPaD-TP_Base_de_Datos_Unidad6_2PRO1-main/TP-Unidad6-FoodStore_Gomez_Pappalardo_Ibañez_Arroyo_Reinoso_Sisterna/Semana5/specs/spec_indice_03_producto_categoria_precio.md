# spec: indice_producto_categoria_precio

Objetivo: optimizar el listado de productos filtrado por categoría y ordenado por precio.

Consulta afectada:
SELECT id_producto, nombre_producto, precio_producto, stock_producto FROM producto
 WHERE categoria_id = :cat AND eliminado = FALSE ORDER BY precio_producto ASC;

Frecuencia: muy alta (catálogo por categoría, navegación del cliente).
Columnas candidatas: categoria_id (filtro exacto), precio_producto (ORDER BY),
nombre_producto + stock_producto (columnas de cobertura).
Tipo propuesto: B-tree compuesto (categoria_id, precio_producto ASC)
INCLUDE (nombre_producto, stock_producto) parcial WHERE eliminado = FALSE.
Criterio de aceptación: desaparece el nodo Sort y el plan usa Index-Only Scan.
