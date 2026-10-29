-- TP4 - Semana 4 - Parte 1
-- Cambios aplicados, justificados contra los nodos del plan baseline
--
-- Diagnostico del plan baseline (ver PLAN BASELINE en resultados.md):
--   * Las 5 tablas tenian reltuples = -1 (NUNCA analizadas). El planificador trabajo
--     con estimaciones por defecto: rows=500 en pedido (hay 5), rows=420 en
--     detalle_pedido (hay 8), rows=50/30 en producto/usuario.
--
-- Cambio 1: ANALYZE. Restaura estadisticas reales; corrige los costos estimados de
--           todos los nodos de join y la eleccion de join order / algoritmo.
ANALYZE categoria;
ANALYZE producto;
ANALYZE usuario;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- Cambio 2: indice de apoyo a la FK detalle_pedido.producto_id.
--           Nodo objetivo del plan baseline Q1:
--             "Hash Join  (cost=37.38..57.44 rows=210 width=28)
--               Hash Cond: (dp.producto_id = pr.id_producto)"
--           detalle_pedido no tenia indice sobre producto_id (solo la UNIQUE
--           (pedido_id, producto_id)); el optimizador debia construir un Hash de
--           producto para el join. El indice habilita el camino Nested Loop +
--           Index Scan en base masiva (traer producto por cada detalle).
--           En esta base chica el planificador lo descarta (ver resultados.md,
--           criterio de aceptacion): con 7 filas construir el Hash es mas barato.
CREATE INDEX idx_detalle_pedido_producto_id ON detalle_pedido(producto_id);