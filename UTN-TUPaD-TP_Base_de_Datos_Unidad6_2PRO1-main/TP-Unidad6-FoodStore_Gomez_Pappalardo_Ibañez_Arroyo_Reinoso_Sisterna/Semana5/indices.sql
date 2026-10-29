-- indices.sql — Parte A: plan de indexado asistido por IA (Unidad 3, Semana 5).
-- Cada índice proviene de un spec en specs/ y fue verificado línea por línea.
-- Convención de borrado lógico de la cátedra: WHERE eliminado = FALSE en índices parciales.
-- No se altera ninguna tabla base, solo se agregan índices.

-- Q1 — Reporte "pedidos confirmados de un mes" (queries.sql F).
-- Filtro: estado_pedido = (igualdad, baja selectividad) + fecha_pedido BETWEEN (rango, alta).
-- Regla B-tree: columna de igualdad primero, luego la de rango.
-- Parcial WHERE eliminado = FALSE porque todos los reportes filtran vigentes.
-- Plan esperado: Seq Scan -> Bitmap Heap Scan + Bitmap Index Scan. Ver informe_mediciones.md §A1.
CREATE INDEX IF NOT EXISTS idx_pedido_estado_fecha
    ON pedido (estado_pedido, fecha_pedido)
    WHERE eliminado = FALSE;

-- Q2 — Top 5 productos más vendidos + facturación por categoría (queries.sql A y B).
-- JOIN detalle_pedido.producto_id = producto.id_producto + filtro eliminado + GROUP BY producto_id.
-- Sin este índice, el JOIN sobre ~10000 filas hace Seq Scan + Hash Join costoso.
-- Plan esperado: Seq Scan sobre detalle_pedido -> Index Scan/Bitmap sobre este índice. Ver §A2.
CREATE INDEX IF NOT EXISTS idx_detalle_producto
    ON detalle_pedido (producto_id)
    WHERE eliminado = FALSE;

-- Q3 — Listado de productos por categoría ordenado por precio (queries.sql G / HU-PROD-01 con filtro).
-- Filtro categoria_id = + ORDER BY precio_producto ASC + columnas de cobertura.
-- Compuesto (categoria_id, precio_producto ASC) elimina el nodo Sort;
-- INCLUDE (nombre_producto, stock_producto) permite Index-Only Scan (covering index, PG 11+).
-- Parcial WHERE eliminado = FALSE (solo vigentes).
-- Plan esperado: Seq Scan + Sort -> Index-Only Scan sin Sort. Ver §A3.
CREATE INDEX IF NOT EXISTS idx_producto_categoria_precio
    ON producto (categoria_id, precio_producto ASC)
    INCLUDE (nombre_producto, stock_producto)
    WHERE eliminado = FALSE;

-- ÍNDICE DESCARTADO POR SOBREINDEXACIÓN (documentado, NO crear):
--   idx_producto_disponible ON producto (disponible)
-- Motivo: columna booleana de cardinalidad 2; el planificador prefiere Seq Scan
-- salvo filtro muy selectivo con parcial. Aporta costo de mantenimiento en cada
-- INSERT/UPDATE sin mejora de lectura. Alternativa redundante también descartada:
-- idx_pedido_usuario ON pedido (usuario_id) porque ya existe idx_pedido_usuario_id
-- de la Semana 3. Ver specs/spec_indice_descartado_disponible.md e informe §A5.
