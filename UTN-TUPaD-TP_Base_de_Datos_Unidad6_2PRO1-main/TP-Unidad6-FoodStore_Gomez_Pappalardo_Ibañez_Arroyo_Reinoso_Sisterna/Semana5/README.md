# Food Store — Unidad 3, Semana 5 (Índices, vistas y vistas materializadas)

## Qué es

Plan de indexado justificado con `EXPLAIN ANALYZE` + 3 vistas (una con criterio
de seguridad) + 1 vista materializada con índice único para `REFRESH
CONCURRENTLY`, sobre el esquema heredado de las Semanas 1–4. Sin modificar tablas base.

## Estructura (exigida por el TP)

```text
Semana 5 CORREGIDA/
├── schema.sql              (heredado, sin modificar)
├── data.sql                (heredado + ampliación de volumen §2: 5000 pedidos / 10000 detalles)
├── queries.sql             (heredado)
├── indices.sql             (nuevo — Parte A, 3 índices aceptados + descartado documentado)
├── views.sql               (nuevo — Partes B y C: 3 vistas + 1 materializada + índice único)
├── specs/                  (8 especificaciones Kiro, una por pieza + una de descarte)
├── mediciones.sql          (protocolo reproducible EXPLAIN / EXCEPT / escritura / MV)
├── informe_mediciones.md   (antes/después, escritura, descarte, equivalencia, MV + refresh)
├── duia.md                 (bitácora IA: herramienta, prompt/spec, propuesta, decisión)
└── README.md               (este archivo)
```

## Requisitos

PostgreSQL 16+, `psql`, Git. Base de prueba dedicada (no la de producción del grupo).

## Cómo reproducir (orden estricto)

```bash
# 1. Base heredada (+ objects.sql de la Semana 4, necesario porque queries.sql usa v_pedidos_resumen)
psql -d foodstore -f schema.sql
psql -d foodstore -f objects.sql      # heredado Semana 4 (no se entrega, solo se reutiliza)
psql -d foodstore -f data.sql         # incluye volumen; verificar ~5004 pedidos / ~10007 detalles

# 2. Medir ANTES (solo índices de Semana 3)
psql -d foodstore -f mediciones.sql   # copiar salidas a informe_mediciones.md (columna "Antes")

# 3. Crear objetos nuevos (en transacción reversible para probar)
psql -d foodstore -f indices.sql
psql -d foodstore -f views.sql

# 4. Medir DESPUÉS y completar informe_mediciones.md (columna "Después" + anexo de planes)
# 5. Refresco de la materializada (cuando haya ventas nuevas):
psql -d foodstore -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;"
```

Protocolo de seguridad de la cátedra: probar primero en copia de la base o en
transacción con `ROLLBACK`, con respaldo previo (`pg_dump`) cuando corresponda.

## Decisiones clave (defensa oral)

- `idx_pedido_estado_fecha (estado, fecha) WHERE eliminado = FALSE`: igualdad
  antes que rango; parcial por borrado lógico.
- `idx_detalle_producto (producto_id) WHERE eliminado = FALSE`: JOIN + GROUP BY
  del Top 5 y facturación.
- `idx_producto_categoria_precio (categoria_id, precio) INCLUDE (nombre, stock)
  WHERE eliminado = FALSE`: covering que elimina el `Sort` (Index-Only Scan).
- Descartado `idx_producto_disponible` (booleana, cardinalidad 2) y duplicado
  `idx_pedido_usuario` (ya existía en Semana 3): sobreindexación.
- `v_seguridad_pedidos_usuarios` oculta `contrasena_usuario`: `SELECT` otorgable
  sin acceso a `usuario`.
- `mv_facturacion_categoria_mes` + `UNIQUE (id_categoria, mes)` → `REFRESH
  CONCURRENTLY` diario nocturno; entre refrescos el dato es al cierre de ayer
  (stale documentado).
