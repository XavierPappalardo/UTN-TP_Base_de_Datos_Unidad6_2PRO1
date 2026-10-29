# informe_mediciones.md — Unidad 3, Semana 5 (Food Store)

Metodología: PostgreSQL **16.2**, base dedicada con volumen (`data.sql` parte 2:
5004 pedidos vigentes, 10007 detalles vigentes, 2014 productos vigentes),
`VACUUM (ANALYZE)` previo, cada `EXPLAIN (ANALYZE, BUFFERS)` ejecutado 3 veces
y se informa la **mediana**. Script reproducible: `mediciones.sql`. Orden: medir
ANTES (solo índices heredados de Semana 3), crear `indices.sql`, medir DESPUÉS.
Q1 usa `BETWEEN CURRENT_DATE - 365 AND CURRENT_DATE` para calzar con el volumen
(fecha de medición: septiembre 2026).

## A1 — Q1: pedidos confirmados de un año (642 filas)

Consulta: `SELECT id_pedido, fecha_pedido, total_pedido FROM pedido WHERE
fecha_pedido BETWEEN CURRENT_DATE - 365 AND CURRENT_DATE AND estado_pedido =
'CONFIRMADO' AND eliminado = FALSE;`
Índice: `idx_pedido_estado_fecha (estado_pedido, fecha_pedido) WHERE eliminado = FALSE`.

ANTES — `Seq Scan on pedido`, filtra 4363 filas, `Buffers: shared hit=150`:
`Execution Time: 0.258 ms` (3 corridas: 0.364 / 0.255 / 0.258).

DESPUÉS — `Bitmap Heap Scan` + `Bitmap Index Scan on idx_pedido_estado_fecha`
(`Heap Blocks: exact=36`), `Buffers: shared hit=39`:
`Execution Time: 0.084 ms` (3 corridas: 0.130 / 0.084 / 0.078).

| Métrica | Antes | Después |
|---|---|---|
| Plan | Seq Scan (hit=150) | Bitmap Heap + Bitmap Index (hit=39) |
| Tiempo mediana | 0.258 ms | 0.084 ms (~3x, -74 % buffers) |

Cambio de plan: SÍ (Seq Scan → Bitmap Heap/Index Scan). Criterio del spec:
CUMPLE en plan y buffers; en tiempo la mejora es ~3x y no 10x porque el dataset
cabe íntegro en caché (`shared hit`); en disco la diferencia sería mayor.

Plan DESPUÉS completo:

```text
Bitmap Heap Scan on pedido  (cost=16.49..182.56 rows=643 width=17) (actual time=0.017..0.063 rows=642 loops=1)
  Recheck Cond: ((estado_pedido = 'CONFIRMADO'::estado_pedido) AND (fecha_pedido >= (CURRENT_DATE - 365)) AND (fecha_pedido <= CURRENT_DATE) AND (NOT eliminado))
  Heap Blocks: exact=36
  Buffers: shared hit=39
  ->  Bitmap Index Scan on idx_pedido_estado_fecha  (cost=0.00..16.33 rows=643 width=0) (actual time=0.014..0.014 rows=642 loops=1)
        Index Cond: ((estado_pedido = 'CONFIRMADO'::estado_pedido) AND (fecha_pedido >= (CURRENT_DATE - 365)) AND (fecha_pedido <= CURRENT_DATE))
        Buffers: shared hit=3
Planning Time: 0.050 ms
Execution Time: 0.084 ms
```

## A2 — Q2: Top 5 productos más vendidos (resultado honesto: SIN cambio)

Consulta: agregado de `queries.sql A` (JOIN + `GROUP BY producto_id` sobre las
10007 filas). Índice: `idx_detalle_producto (producto_id) WHERE eliminado = FALSE`.

ANTES: `Seq Scan on detalle_pedido` + `Hash Join` + `HashAggregate`:
`Execution Time: 2.203 ms` (2.203 / 2.140 / 2.222).
DESPUÉS: **mismo plan** (`Seq Scan` + `Hash Join`):
`Execution Time: 2.177 ms` (2.236 / 2.177 / 2.133).

| Métrica | Antes | Después |
|---|---|---|
| Plan | Seq Scan + Hash Join + HashAggregate | Idéntico (correcto) |
| Tiempo mediana | 2.203 ms | 2.177 ms (sin mejora) |

Sin cambio de plan, y es lo esperado: un agregado TOTAL debe leer las 10007
filas igual; ningún índice B-tree evita ese escaneo. El índice se CONSERVA igual
porque su caso de uso es el acceso SELECTIVO por producto (ver A2b) y los
chequeos de FK/JOINs filtrados, no el full scan. Esto es exactamente lo que pide
la cátedra: medir antes de afirmar que "un índice siempre ayuda".

## A2b — Q2 complementaria: ventas de un producto (770 filas, selectiva)

Consulta: `SELECT pedido_id, cantidad, subtotal FROM detalle_pedido WHERE
producto_id = 4 AND eliminado = FALSE ORDER BY pedido_id;`

ANTES — `Seq Scan` (descarta 9238 filas, hit=104) + `Sort`:
`Execution Time: 0.629 ms` (0.724 / 0.629 / 0.568).
DESPUÉS — `Bitmap Heap Scan` + `Bitmap Index Scan on idx_detalle_producto`
(`Heap Blocks: exact=104`, hit=106):
`Execution Time: 0.208 ms` (0.326 / 0.197 / 0.208).

| Métrica | Antes | Después |
|---|---|---|
| Plan | Seq Scan + Sort (hit=104) | Bitmap Heap + Bitmap Index (hit=106, heap exacto) |
| Tiempo mediana | 0.629 ms | 0.208 ms (~3x) |

Cambio de plan: SÍ. El índice demuestra su valor en el acceso selectivo.

## A3 — Q3: productos de categoría 1 ordenados por precio (2003 filas)

Consulta: `... WHERE categoria_id = 1 AND eliminado = FALSE ORDER BY
precio_producto ASC;` (2003 filas gracias al volumen de catálogo de `data.sql`
§2.4; con solo 15 productos el planificador usa Seq Scan con o sin índice).
Índice covering: `idx_producto_categoria_precio (categoria_id, precio_producto)
INCLUDE (nombre, stock) WHERE eliminado = FALSE`.

SIN ÍNDICE — `Seq Scan` + `Sort (quicksort, 158kB)`:
`Execution Time: 0.485 ms` (0.554 / 0.485 / 0.482).
CON ÍNDICE — `Index Scan using idx_producto_categoria_precio`, **nodo `Sort`
eliminado**: `Execution Time: 0.235 ms` (0.302 / 0.235 / 0.214).

| Métrica | Sin índice | Con índice |
|---|---|---|
| Plan | Seq Scan + Sort | Index Scan, sin Sort |
| Tiempo mediana | 0.485 ms | 0.235 ms (~2x, sin Sort) |

Criterio del spec: CUMPLE (desaparece el `Sort`; con catálogo mayor la brecha
crece porque el Sort es O(n log n) y el Index Scan devuelve ordenado).

## A4 — Costo de los índices sobre la escritura (500 INSERT en detalle_pedido)

Prueba: `EXPLAIN (ANALYZE)` de 500 `INSERT` (`mediciones.sql` §A4) con
`ROLLBACK` posterior, antes y después de `indices.sql`.

ANTES: `Execution Time: 12.275 ms` (triggers FK + `trg_subtotal` + `trg_total_ins`
dominan el costo).
DESPUÉS: `Execution Time: 13.553 ms`.

| Carga 500 INSERT | Antes | Después |
|---|---|---|
| Tiempo | 12.275 ms | 13.553 ms (+10.4 %) |

Sobrecarga moderada (+10 %), aceptable frente a las mejoras de lectura (3x en
Q1/Q2b, eliminación del Sort en Q3, 167x en el reporte C). Los 3 índices son
parciales (solo filas vigentes), lo que acota el mantenimiento.

## A5 — Índice descartado por sobreindexación

Se descarta `idx_producto_disponible ON producto (disponible)`: booleana de
cardinalidad 2; sin parcial selectivo el optimizador elige Seq Scan igual, y el
índice solo encarece INSERT/UPDATE. También se descarta `idx_pedido_usuario ON
pedido (usuario_id)` por redundante con `idx_pedido_usuario_id` de Semana 3.
Ninguno figura en `indices.sql`. Ver `specs/spec_indice_descartado_disponible.md`
y `duia.md` fila 3. Decisión humana: no delegada.

## B — Verificación de equivalencia de vistas (Parte B)

Método: consulta manual `EXCEPT` vista y vista `EXCEPT` consulta manual, en ambas
direcciones (`mediciones.sql` §B). Resultado real en PG 16.2:

- B1a `v_reporte_productos_categorias`: **0 filas** — B1b: **0 filas**. VÁLIDA.
- B2a `v_seguridad_pedidos_usuarios`: **0 filas** — B2b: **0 filas**. VÁLIDA.
- B3a `v_reporte_detalle_pedido_producto`: **0 filas** — B3b: **0 filas**. VÁLIDA.

Seguridad B2: `information_schema.columns` de la vista lista
`apellido_usuario, estado_pedido, fecha_pedido, forma_pago, id_pedido,
id_usuario, mail_usuario, nombre_usuario, total_pedido` —
`contrasena_usuario` **NO expuesta** (`contrasena_expuesta=False`). Se puede
otorgar `SELECT` sobre la vista sin acceso a `usuario`.

## C — Vista materializada (Parte C)

Reporte: facturación por categoría y mes (`queries.sql B`, 4 JOINs + `GROUP BY`
sobre 10007 filas → 125 grupos). Objeto: `mv_facturacion_categoria_mes ...
WITH DATA` (125 filas) + `UNIQUE (id_categoria, mes)`.

Consulta original: `HashAggregate` + 3 `Hash Joins` (`Seq Scan` sobre
detalle_pedido y pedido, hit=266): `Execution Time: 7.027 ms`
(7.980 / 6.887 / 7.027), wall 6.25 ms.
`SELECT * FROM mv_facturacion_categoria_mes`: `Seq Scan` sobre 125 filas
preagregadas (hit=1): `Execution Time: 0.042 ms` (0.048 / 0.042 / 0.037),
wall 0.20 ms.

| Reporte | Tiempo real |
|---|---|
| Consulta original | 7.027 ms |
| `SELECT` sobre la MV | 0.042 ms (**~167x**) |

`REFRESH MATERIALIZED VIEW CONCURRENTLY` verificado OK (16.1 ms, 125 filas
tras el refresh). El índice único es lo que lo hace posible.
Frecuencia recomendada: **diaria nocturna** (tras cierre de caja); el dashboard
se lee varias veces al día pero tolera desfase. Implicancia: entre refrescos la
MV devuelve datos al cierre de ayer (_stale_ documentado a usuarios);
`CONCURRENTLY` refresca sin bloquear lecturas. Descartado: refresco por trigger
en cada venta (encarece escritura y anula el beneficio de materializar).

## Anexo — entorno

PostgreSQL 16.2, base dedicada recién creada, `VACUUM (ANALYZE)` previo a cada
batería. Conteos: 5004 pedidos / 10007 detalles / 2014 productos vigentes.
Planes completos de Q1–Q3/Q2b transcriptos arriba; QB-ORIG y QMV en §C.
