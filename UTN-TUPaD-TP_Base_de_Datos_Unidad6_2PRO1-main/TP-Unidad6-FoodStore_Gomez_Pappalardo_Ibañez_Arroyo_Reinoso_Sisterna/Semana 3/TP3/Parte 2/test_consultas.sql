-- Consulta 1
EXPLAIN ANALYZE
SELECT c.nombres, c.apellidos, c.correo, SUM(co.monto) as total_gastado
FROM cliente c
JOIN compra co ON c.id = co.cliente_id
WHERE co.dia >= (CURRENT_DATE - INTERVAL '30 days')
  AND co.situacion = 'TERMINADO'
GROUP BY c.id, c.nombres, c.apellidos, c.correo
ORDER BY total_gastado DESC
LIMIT 50;

-- Consulta 2 sin optimizar
EXPLAIN ANALYZE
SELECT a.titulo, a.valor, r.titulo AS rubro
FROM articulo a
JOIN rubro r ON a.rubro_id = r.id
WHERE a.descripcion ILIKE '%dulce%'
  AND a.activo = TRUE
ORDER BY a.valor ASC;

-- Consulta 2 optimizada
EXPLAIN ANALYZE
SELECT a.titulo, a.valor, r.titulo AS rubro
FROM articulo a
JOIN rubro r ON a.rubro_id = r.id
WHERE to_tsvector('spanish', a.descripcion) @@ to_tsquery('spanish', 'dulce')
  AND a.activo = TRUE
ORDER BY a.valor ASC;

-- Consulta 3
EXPLAIN ANALYZE
SELECT a.titulo, SUM(dc.unidades) AS unidades_vendidas, SUM(dc.parcial) AS recaudacion_total
FROM articulo a
JOIN detalle_compra dc ON a.id = dc.articulo_id
GROUP BY a.id, a.titulo
ORDER BY recaudacion_total DESC
LIMIT 10;