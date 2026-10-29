-- Parte 5: Competencia de optimización

-- 1. Consulta original (Lenta)
EXPLAIN ANALYZE
SELECT a.id, a.titulo, a.valor, a.unidades
FROM articulo a
WHERE a.rubro_id = 2
  AND a.valor BETWEEN 1000 AND 3000
  AND a.eliminado = FALSE
ORDER BY a.valor ASC;

-- 2. Índice ganador propuesto
CREATE INDEX idx_articulo_competencia 
ON articulo (rubro_id, valor ASC) 
INCLUDE (titulo, unidades)
WHERE eliminado = FALSE;

-- 3. Consulta optimizada (Index Only Scan)
EXPLAIN ANALYZE
SELECT a.id, a.titulo, a.valor, a.unidades
FROM articulo a
WHERE a.rubro_id = 2
  AND a.valor BETWEEN 1000 AND 3000
  AND a.eliminado = FALSE
ORDER BY a.valor ASC;