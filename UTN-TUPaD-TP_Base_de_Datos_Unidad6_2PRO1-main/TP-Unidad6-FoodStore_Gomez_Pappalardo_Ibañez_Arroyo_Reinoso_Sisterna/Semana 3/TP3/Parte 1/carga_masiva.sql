-- TP3 - Carga masiva simple
-- 50.000 articulos parejos en rubros existentes (valor 500-5000, unidades 0-200)
-- 20.000 clientes + 200.000 compras con 1 detalle c/u (200.000 detalles)
-- Solo toca articulo, cliente, compra, detalle_compra. No modifica rubro.
-- Requiere schema.sql + data.sql ya ejecutados. Usar en DB de trabajo:
--   BEGIN; \i TP3/carga_masiva.sql; -- verificar; ROLLBACK o COMMIT;

begin;
-- 1) 50.000 articulos
INSERT INTO articulo (titulo, valor, descripcion, unidades, rubro_id)
SELECT
    'Articulo ' || lpad(gs::text, 5, '0')  AS titulo,
    (500 + random() * 4500)::numeric(10,2) AS valor,
    'Articulo generado ' || gs             AS descripcion,
    floor(random() * 201)::int             AS unidades,
    ((gs - 1) % 4 + 1)::bigint            AS rubro_id
FROM generate_series(1, 50000) AS gs;

-- 2) 20.000 clientes
INSERT INTO cliente (nombres, apellidos, correo, telefono, clave, perfil)
SELECT
    'Nombre' || gs                                          AS nombres,
    'Apellido' || gs                                        AS apellidos,
    'u' || lpad(gs::text, 6, '0') || '@replica.test'        AS correo,
    '11' || lpad((floor(random()*90000000)+10000000)::text, 8, '0') AS telefono,
    'hash_' || gs                                           AS clave,
    (CASE WHEN random() < 0.05 THEN 'ADMIN'::perfil ELSE 'USUARIO'::perfil END) AS perfil
FROM generate_series(1, 20000) AS gs;

-- 3) 200.000 compras - cliente_id de ids reales (evita error FK 23503 por huecos de identity)
WITH user_ids AS (SELECT array_agg(id) AS ids FROM cliente)
INSERT INTO compra (dia, situacion, monto, modalidad, cliente_id)
SELECT
    (CURRENT_DATE - (floor(random()*730))::int) AS dia,
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO'])[1+floor(random()*4)::int]::situacion_compra,
    0,
    (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO'])[1+floor(random()*3)::int]::modalidad_pago,
    ids[1 + floor(random()*array_length(ids,1))::int]
FROM generate_series(1, 200000) AS gs
CROSS JOIN user_ids;

-- 4) 200.000 detalles - 1 por compra, articulo tomado de ids reales
WITH articulo_ids AS (SELECT array_agg(id) AS ids FROM articulo),
     nuevas AS (SELECT id AS compra_id FROM compra ORDER BY id DESC LIMIT 200000)
INSERT INTO detalle_compra (unidades, valor_unitario, parcial, compra_id, articulo_id)
SELECT
    (1 + floor(random()*5))::int AS unidades,
    a.valor                      AS valor_unitario,
    ((1 + floor(random()*5))::int * a.valor)::numeric(12,2) AS parcial,
    nv.compra_id,
    a.id
FROM nuevas nv
CROSS JOIN articulo_ids
CROSS JOIN LATERAL (
    SELECT id, valor FROM articulo
    WHERE id = articulo_ids.ids[1 + floor(random()*array_length(articulo_ids.ids,1))::int]
) a;

-- 5) Recalcular montos de las 200k compras nuevas
UPDATE compra c SET monto = s.suma
FROM (
    SELECT compra_id, SUM(parcial)::numeric(12,2) AS suma
    FROM detalle_compra
    WHERE compra_id IN (SELECT id FROM compra ORDER BY id DESC LIMIT 200000)
    GROUP BY compra_id
) s
WHERE c.id = s.compra_id;

commit;

-- Verificacion carga masiva correctamente
SELECT 'articulo' AS tabla, count(*) FROM articulo
UNION ALL SELECT 'cliente', count(*) FROM cliente
UNION ALL SELECT 'compra', count(*) FROM compra
UNION ALL SELECT 'detalle_compra', count(*) FROM detalle_compra;