# TP4 - Parte 1 - Tabla de resultados y analisis de planes

Nota metodologica: se trabajo sobre la base `food_store` disponible en el servidor local,
que NO esta poblada masivamente (5 usuarios, 5 pedidos, 8 detalles, 15 productos). La
practica pide medir sobre base masiva; se registro la decision de avanzar con los datos
actuales y los tiempos resultan poco representativos de una base real. Los allazgos de
plan y la metodologia son validos; las mejoras numericas deben leerse con esa salvedad.

## Tabla 1.2 - Resultados

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (despues) | Mejora |
|---|---|---|---|---|
| Q1 - Facturacion por categoria y mes (cruza detalle_pedido, pedido, producto, categoria) | 3x Hash Join | ANALYZE en las 5 tablas (estadisticas reales) + `CREATE INDEX idx_detalle_pedido_producto_id ON detalle_pedido(producto_id)` | 3x Hash Join (sin cambio de algoritmo) | 6.775 ms -> 0.301 ms (**22.5x**) |
| Q2 - Ranking de usuarios por gasto (cruza usuario, pedido, detalle_pedido) | 2x Hash Join | ANALYZE en las 5 tablas | 2x Hash Join (sin cambio de algoritmo) | 1.509 ms -> 0.455 ms (**3.3x**) |

Tiempos: `Execution Time` de `EXPLAIN (ANALYZE, BUFFERS)`.

## Diagnostico del plan baseline

Antes de cualquier cambio, las 5 tablas tenian `reltuples = -1` (jamas se ejecuto ANALYZE;
`pg_stat_all_tables.n_live_tup` mostraba los valores reales: producto=15, detalle_pedido=8,
categoria=6, usuario=5, pedido=5). El planificador uso estimaciones por defecto:

- `pedido`: estimado **500 filas**, real **4** (tras filtrar `eliminado = FALSE`).
- `detalle_pedido`: estimado **420 filas**, real **7**.
- `producto`: estimado **50 filas**, real **15**.
- `categoria`: estimado **110 filas**, real **6**.
- `usuario`: estimado **30 filas**, real **4**.

Con esas estimaciones infladas, todos los nodos de join mostraban costos altos y ancestros
(hash tables con buckets 1024) desproporcionados. La mejora principal (Q1 22.5x) viene de
corregir esas estadisticas: el plan pasa a decidir sobre costos reales.

## Plan BASELINE Q1 (antes)

```
Sort  (cost=84.89..85.41 rows=210) (actual time=4.240..4.243 rows=7)
  -> HashAggregate (Group Key: categoria, mes) (actual rows=7)
     -> Hash Join  (cost=49.85..71.54)   Hash Cond: (pr.categoria_id = c.id_categoria)
        -> Hash Join (cost=37.38..57.44) Hash Cond: (dp.producto_id = pr.id_producto)
           -> Hash Join (cost=26.25..45.75) Hash Cond: (dp.pedido_id = ped.id_pedido)
              -> Seq Scan on detalle_pedido dp   (est. rows=420, real 7)
              -> Hash -> Seq Scan on pedido ped  (est. rows=500, real 4)
           -> Hash -> Seq Scan on producto pr    (est. rows=50, real 15)
        -> Hash -> Seq Scan on categoria c       (est. rows=110, real 6)
Execution Time: 6.775 ms
```

## Plan DESPUES Q1 (analizado + indice creado)

```
Sort  (cost=4.97..4.99 rows=6) (actual time=0.177..0.179 rows=7)
  -> HashAggregate (Group Key: categoria, mes) (actual rows=7)
     -> Hash Join  (cost=3.42..4.74)   Hash Cond: (pr.categoria_id = c.id_categoria)
        -> Hash Join (cost=2.28..3.55) Hash Cond: (pr.id_producto = dp.producto_id)
           -> Seq Scan on producto pr  (rows=15)
           -> Hash -> Hash Join (cost=1.10..2.21)
                        Hash Cond: (dp.pedido_id = ped.id_pedido)
                    -> Seq Scan on detalle_pedido dp (rows=7)
                    -> Hash -> Seq Scan on pedido ped (rows=4)
        -> Hash -> Seq Scan on categoria c (rows=6)
Execution Time: 0.301 ms
```

Observaciones:
- Estimaciones correctas (rows=4-15) y join order mas barata (primero producto, luego el
  subconjunto detalle/pedido).
- El indice `idx_detalle_pedido_producto_id` NO se usa: el optimizador mantiene
  `Hash Join (pr.id_producto = dp.producto_id)` con Seq Scan. Con 7-15 filas, construir
  el Hash es mas barato que sondear un indice (cost 2.28 vs. el camino indexado).

## Plan BASELINE Q2 (antes)

```
Sort -> WindowAgg (rank) 
  -> Sort (sum gasto DESC)
     -> HashAggregate (Group Key: u.id_usuario)
        -> Hash Join (dp.pedido_id = ped.id_pedido)   [detalle_pedido externa, pedido en Hash]
           -> Seq Scan detalle_pedido (est 420, real 7)
           -> Hash -> Hash Join (ped.usuario_id = u.id_usuario)
                -> Seq Scan pedido (est 500, real 4)
                -> Hash -> Seq Scan usuario (est 30, real 4)
Execution Time: 1.509 ms
```

## Plan DESPUES Q2 (analizado)

```
Sort -> WindowAgg (rank)
  -> Sort (sum gasto DESC)
     -> HashAggregate (Group Key: u.id_usuario)
        -> Hash Join (ped.usuario_id = u.id_usuario)
           -> Hash Join (dp.pedido_id = ped.id_pedido)
              -> Seq Scan detalle_pedido (rows=7)
              -> Hash -> Seq Scan pedido (rows=4)
           -> Hash -> Seq Scan usuario (rows=4)
Execution Time: 0.455 ms
```

Observacion: cambio de join order (el join usuario<-pedido queda afuera) y estimaciones
reales. Algoritmo: 2x Hash Join en ambos casos.

## Criterio de aceptacion (defensa oral)

1. Ninguna propuesta se aplico sin entenderla: ANALYZE era evidente (reltuples=-1) y el
   indice se justifico contra el nodo `Hash Cond: (dp.producto_id = pr.id_producto)`.
2. "Si agregar un indice cambia el algoritmo de join... se documenta y se explica por que
   el nuevo plan resulto mas o menos conveniente". En este caso el algoritmo NO cambio
   (se mantuvo Hash Join). Explicacion: con <20 filas por tabla, el costo de construir un
   Hash y sondearlo es menor que el de recorrer un indice B-tree (que agrega un nivel de
   indireccion). El indice queda justificado para la base masiva: cuando detalle_pedido
   tenga cientos de miles de filas y el join venga conducido por pocas filas de producto,
   el planificador podra elegir Nested Loop + Index Scan sobre `idx_detalle_pedido_producto_id`.
3. La mejora medida (principalmente por ANALYZE) se explica por estimaciones de filas
   infladas 10x que distorsionaban costos, buffers y eleccion del plan.