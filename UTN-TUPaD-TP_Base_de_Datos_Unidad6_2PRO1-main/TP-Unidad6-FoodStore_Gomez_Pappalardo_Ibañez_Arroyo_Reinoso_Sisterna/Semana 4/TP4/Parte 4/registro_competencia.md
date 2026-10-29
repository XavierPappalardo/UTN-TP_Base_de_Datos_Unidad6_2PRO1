# TP4 - Parte 4 - Registro de competencia

Fecha: 2026-09-14. DB: `food_store` local (PostgreSQL 16).

Salvedad registrada: la base compartida NO esta poblada masivamente (5 usuarios, 5
pedidos, 8 detalles, 15 productos), decision documentada al inicio de la practica. La
competencia se registro igualmente sobre la base disponible; el tiempo "antes" proviene
del plan baseline de la Parte 1 (misma cadena de joins: detalle -> pedido -> producto ->
categoria, con estadisticas por defecto), porque el estado pre-cambios ya no existe en el
servidor.

Plan "despues" (cambiando el estado analizado + indice):

```
Sort -> GroupAggregate (facturado)
  -> Sort (Group Key: id_usuario, id_categoria)
     -> Hash Join (pr.categoria_id = c.id_categoria)
        -> Hash Join (pr.id_producto = dp.producto_id)
           -> Seq Scan producto (rows=15)
           -> Hash -> Hash Join (ped.usuario_id = u.id_usuario)
                -> Hash Join (dp.pedido_id = ped.id_pedido)
                   -> Seq Scan detalle_pedido (rows=7)
                   -> Hash -> Seq Scan pedido (rows=4)
                -> Hash -> Seq Scan usuario (rows=4)
        -> Hash -> Seq Scan categoria (rows=5)
Execution Time: 0.328 ms
```

## Registro

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo despues (ms) | Mejora (x) |
|---|---|---|---|---|
| Gomez - Pappalardo - Ibanez - Arroyo - Reinoso - Sisterna | ANALYZE correctivo (estadisticas reales, baseline con reltuples=-1) + indice `idx_detalle_pedido_producto_id` (reutilizado de Parte 1, justificado en nodo `Hash Cond: dp.producto_id = pr.id_producto`) | 6.775 (plan baseline Parte 1, misma cadena de joins) | 0.328 | **20.7** |

## Propuestas de IA evaluadas y rechazadas (se documentan por protocolo)

| Propuesta de la IA | Resultado | Motivo |
|---|---|---|
| Reordenar joins con `categoria` de primera (join order nuevo) | No aplicada | En el plan real el planificador ya eligio el join order mas barato (estimaciones corregidas por ANALYZE); forzar un orden distinto con `join_collapse_limit` o reescritura solo empeora el plan en base chica y no se justifica por ningun nodo |
| Expresar totales con subconsultas correlacionadas para evitar el GroupAggregate | No aplicada | Altera la semantica original (requiere reespecificar la consigna) y agrega un nivel de agregacion redundante; no hay evidencia en el plan de que el GroupAggregate sea un nodo caro |
| Indices sobre `pedido(fecha_pedido)` para optimizar GROUP BY mensual | Rechazada (descartada) | El plan no muestra Sort/Index Scan sobre fecha que justifique el indice; con datos de prueba no cambia nada y en base masiva el GROUP BY por `date_trunc(mes)` requiere el sort de igual forma |

## Nota de defensa

La mejora real medida es 0.328 ms tras ANALYZE (antes 6.775 ms con estimaciones por
defecto). El indice adicional no cambia el plan en base chica; su justificacion queda
documentada para la base masiva (camino Nested Loop + Index Scan al conducir el join
desde pocas filas de producto).