-- data.sql
-- TPI Base de Datos - Food Store — HEREDADO Semana 2 + AMPLIACIÓN DE VOLUMEN Semana 5.
-- Parte 1 (líneas 1-120): datos base originales, SIN MODIFICAR.
-- Parte 2 (final): bloque de volumen exigido por el TP (varios miles de filas en
-- pedido y detalle_pedido para que EXPLAIN ANALYZE muestre diferencias de plan).
-- Orden de ejecución: schema.sql -> objects.sql -> data.sql
--

BEGIN;

--
-- Categorías
--
INSERT INTO categoria (nombre_categoria, descripcion_categoria) VALUES
 ('Pizzas',        'Pizzas artesanales a la piedra'),
 ('Empanadas',     'Empanadas caseras horneadas'),
 ('Hamburguesas',  'Hamburguesas smash y clásicas'),
 ('Bebidas',       'Bebidas frías y calientes'),
 ('Postres',       'Postres y dulces caseros');

-- Categoría dada de baja logica, para probar v_categorias_vigentes
INSERT INTO categoria (nombre_categoria, descripcion_categoria, eliminado) VALUES
 ('Descontinuados', 'Categoría de baja, solo para pruebas de soft delete', TRUE);

--
-- Productos
--

-- Pizzas
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Muzzarella',   'Pizza clásica de muzzarella',        4500.00, 20, TRUE, 1),
 ('Napolitana',   'Muzzarella, tomate y ajo',           5200.00, 15, TRUE, 1),
 ('Fugazzeta',    'Pizza de cebolla y muzzarella',      4800.00, 10, TRUE, 1);

-- Empanadas
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Empanada de carne',          'Carne cortada a cuchillo',   700.00, 100, TRUE, 2),
 ('Empanada de pollo',          'Pollo con verdeo',           700.00, 100, TRUE, 2),
 ('Empanada jamón y queso',     'Jamón cocido y muzzarella',  650.00,  80, TRUE, 2);

-- Hamburguesas
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Hamburguesa clásica',        'Carne, lechuga, tomate y mayonesa', 3200.00, 25, TRUE, 3),
 ('Hamburguesa doble cheddar',  'Doble carne y doble cheddar',       4100.00, 20, TRUE, 3);

-- Bebidas
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Coca-Cola 500ml',          'Gaseosa línea Coca-Cola',   1500.00, 60, TRUE, 4),
 ('Agua mineral 500ml',       'Agua sin gas',               900.00, 60, TRUE, 4),
 ('Cerveza artesanal IPA',    'Botella 473ml',             1800.00, 40, TRUE, 4);

-- Postres
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Flan casero',   'Con dulce de leche y crema', 1200.00, 30, TRUE, 5),
 ('Tiramisú',      'Receta italiana clásica',    1800.00, 20, TRUE, 5);

-- Producto dado de baja logica, para probar v_productos_vigentes
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id, eliminado) VALUES
 ('Pizza de rúcula', 'Descontinuada del menú', 5000.00, 0, TRUE, 1, TRUE);

-- Producto sin stock y no disponible, para probar las validaciones de sp_crear_pedido
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id) VALUES
 ('Hamburguesa vegetariana', 'Sin stock actualmente', 3500.00, 0, FALSE, 3);

--
-- Usuarios
--

INSERT INTO usuario (nombre_usuario, apellido_usuario, mail_usuario, celular_usuario, contrasena_usuario, rol) VALUES
 ('Admin',  'FoodStore', 'admin@foodstore.com', '2610000000', 'hash_admin',  'ADMIN'),
 ('Juan',   'Pérez',     'juan@x.com',          '2611234567', 'hash_juan',   'USUARIO'),
 ('Ana',    'Garis',     'ana@x.com',           '2612345678', 'hash_ana',    'USUARIO'),
 ('Bruno',  'Ledesma',   'bruno@x.com',         '2613456789', 'hash_bruno',  'USUARIO');

-- Usuario dado de baja logica
INSERT INTO usuario (nombre_usuario, apellido_usuario, mail_usuario, celular_usuario, contrasena_usuario, rol, eliminado) VALUES
 ('Carla', 'Suárez', 'carla@x.com', '2614567890', 'hash_carla', 'USUARIO', TRUE);

-- Pedido 1: Juan
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago, usuario_id) VALUES
 ('2026-06-10', 'CONFIRMADO', 10500.00, 'EFECTIVO', 2);

INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id) VALUES
 (2, 4500.00, 9000.00, 1, 1),   -- Muzzarella
 (1, 1500.00, 1500.00, 1, 9);   -- Coca-Cola

-- Pedido 2: Ana
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago, usuario_id) VALUES
 ('2026-07-02', 'TERMINADO', 7300.00, 'TARJETA', 3);

INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id) VALUES
 (1, 5200.00, 5200.00, 2, 2),   -- Napolitana
 (3,  700.00, 2100.00, 2, 4);   -- Empanada de carne

-- Pedido 3: Juan
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago, usuario_id) VALUES
 ('2026-07-20', 'PENDIENTE', 6800.00, 'TRANSFERENCIA', 2);

INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id) VALUES
 (1, 3200.00, 3200.00, 3, 7),   -- Hamburguesa clásica
 (2, 1800.00, 3600.00, 3, 11);  -- Cerveza artesanal IPA

-- Pedido 4: Bruno
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago, usuario_id) VALUES
 ('2026-08-05', 'CANCELADO', 4800.00, 'EFECTIVO', 4);

INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id) VALUES
 (1, 4800.00, 4800.00, 4, 3);   -- Fugazzeta

-- Pedido 5: Ana
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago, usuario_id) VALUES
 ('2026-08-15', 'CONFIRMADO', 1800.00, 'EFECTIVO', 3);

INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id) VALUES
 (1, 1800.00, 1800.00, 5, 13);  -- Tiramisú

-- Baja lógica del pedido 5
UPDATE detalle_pedido SET eliminado = TRUE WHERE pedido_id = 5;
UPDATE pedido         SET eliminado = TRUE WHERE id_pedido = 5;

COMMIT;

-- ============================================================================
-- PARTE 2 — AMPLIACIÓN DE VOLUMEN (Semana 5, exigencia del punto 3 del TP).
-- Genera 5000 pedidos + 10000 detalles adicionales (~2 detalles por pedido).
-- No modifica filas base; usa generate_series, es determinista y respeta:
--   * FKs a usuario (2,3,4 vigentes) y producto (1..13 vigentes),
--   * UNIQUE (pedido_id, producto_id) — los 2 detalles usan productos distintos,
--   * triggers de subtotal/total (el total se recalcula solo),
--   * borrado lógico (todo con eliminado = FALSE).
-- ============================================================================

-- 2.1) 5000 pedidos nuevos (ids 6..5005), fechas últimos 2 años, estados y pagos rotados.
INSERT INTO pedido (fecha_pedido, estado_pedido, forma_pago, usuario_id, eliminado)
SELECT (CURRENT_DATE - (g % 730))::DATE,
       (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO'])[1 + (g % 4)]::estado_pedido,
       (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO'])[1 + (g % 3)]::forma_pago,
       2 + (g % 3),   -- rota entre usuarios vigentes 2, 3, 4
       FALSE
FROM generate_series(1, 5000) AS g;

-- 2.2) Detalle #1 por pedido nuevo (5000 filas).
INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id)
SELECT 1 + (p.id_pedido % 4),
       pr.precio_producto,
       (1 + (p.id_pedido % 4)) * pr.precio_producto,
       p.id_pedido,
       pr.id_producto
FROM pedido p
JOIN producto pr ON pr.id_producto = (p.id_pedido % 13) + 1
WHERE p.id_pedido > 5 AND p.eliminado = FALSE;

-- 2.3) Detalle #2 por pedido nuevo, producto distinto al #1 (otras 5000 filas).
INSERT INTO detalle_pedido (cantidad_detallepedido, precio_unitario, subtotal_detallepedido, pedido_id, producto_id)
SELECT 1 + ((p.id_pedido + 3) % 4),
       pr.precio_producto,
       (1 + ((p.id_pedido + 3) % 4)) * pr.precio_producto,
       p.id_pedido,
       pr.id_producto
FROM pedido p
JOIN producto pr ON pr.id_producto = ((p.id_pedido + 5) % 13) + 1
WHERE p.id_pedido > 5 AND p.eliminado = FALSE;

-- 2.4) Volumen de catálogo: 2000 productos en categoría 1 para que el índice
-- covering idx_producto_categoria_precio muestre Index Scan sin Sort (con solo
-- 15 productos el planificador siempre elige Seq Scan). No afecta FKs (los
-- detalles usan productos 1..13) ni reportes (sin ventas no agregan filas).
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, disponible, categoria_id)
SELECT 'ProdVol-' || g, 'volumen categoria 1', 100 + (g % 5000), 10, TRUE, 1
FROM generate_series(1, 2000) AS g;

-- 2.5) Estadísticas para que el planificador vea el volumen real.
VACUUM (ANALYZE) pedido;
VACUUM (ANALYZE) detalle_pedido;
VACUUM (ANALYZE) producto;

-- Verificación esperada tras esta sección:
-- SELECT count(*) FROM pedido WHERE eliminado = FALSE;          -- 5004
-- SELECT count(*) FROM detalle_pedido WHERE eliminado = FALSE;  -- 10007
-- SELECT count(*) FROM producto WHERE eliminado = FALSE;        -- 2014
