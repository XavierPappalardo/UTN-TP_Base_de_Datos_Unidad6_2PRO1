# Declaracion de Uso de IA (DUIA) - TP4 - Semana 4

Herramientas: OpenCode (Big Pickle) como asistente; psql/DBeaver para ejecucion y
medicion. Se completa una fila por uso relevante.

## Parte 1 - Laboratorio de consultas analiticas

| Herramienta | Para que se uso | Prompt / spec (resumen) | Se acepto / se descarto - por que |
|---|---|---|---|
| OpenCode | Diagnosticar el plan baseline | "Ejecuta EXPLAIN (ANALYZE, BUFFERS) de (B) facturacion por categoria y mes y (C) ranking de usuarios por gasto de queries.sql; identifica el algoritmo de join de cada nodo y que leve autoridad tiene el optimizador" | Se acepto: se identificaron 3x Hash Join (Q1) y 2x Hash Join (Q2), y el hallazgo de que las 5 tablas tenian reltuples=-1 (nunca ANALYZE) evidenciado por estimaciones 10x |
| OpenCode | Proponer cambios justificados | "A partir del nodo 'Hash Cond: (dp.producto_id = pr.id_producto)' y de las estimaciones infladas, proponi ANALYZE y/o indices adicionales justificando cada uno en ese nodo y no en generalidades" | Aceptado: ANALYZE de las 5 tablas (arregla costos) + `idx_detalle_pedido_producto_id` (no existia indice sobre la FK detalle_pedido.producto_id) |
| OpenCode | Re-medir y explicar el resultado | "Medi de nuevo el mismo script y explicame por que el algoritmo de join no cambio" | Aceptado como evidencia honesta: el planificador mantuvo Hash Join (indice no usado con 7 filas; construir Hash es mas barato). Se documento el caso como exige el criterio de aceptacion |
| OpenCode | Evaluar "indices sobre pedido(fecha_pedido) para el GROUP BY mensual" | Propuesta de indice sobre fecha_pedido | Descartado: el plan no muestra ningun nodo Sort/Scan sobre fecha que lo justifique; en base chica no cambia y en masiva el date_trunc(mes) igual requiere sort |

## Parte 2 - Lectura critica de planes

| Herramienta | Para que se uso | Prompt / spec (resumen) | Se acepto / se descarto - por que |
|---|---|---|---|
| OpenCode | Generar la explicacion nodo a nodo del plan baseline de Q1 | "Explica este EXPLAIN en lenguaje natural, nodo por nodo, solo con el texto del plan" | Se contrasto contra el plan real: la IA erro en 3 de los puntos criticos (tipo de join, externa/interna del hash, costo estimado vs tiempo real) y en el group key; se documento en lectura_critica.md |

## Parte 3 - Consultas resumen, ranking y subconsultas

| Herramienta | Para que se uso | Prompt / spec (resumen) | Se acepto / se descarto - por que |
|---|---|---|---|
| OpenCode | Generar SQL del ranking desde la spec de catedra | Spec textual del ranking de usuarios por gasto (ver ranking_v1.sql) | Aceptado: v1 con RANK() y v2 con estructura distinta (CTE + conteo de competidores); verificadas equivalentes por EXCEPT (0 filas en ambos sentidos) |
| OpenCode | Generar la subconsulta correlacionada desde spec | Spec de productos que superan el promedio de su categoria | PRIMER version aceptada NO: fallaba la equivalencia (0 vs 2 filas). Se descarto y se corrigio el GROUP BY del subquery agregando id_producto; el caso se documento porque demuestra el riesgo de "parecer equivalentes sin serlo" |
| OpenCode | Verificar equivalencia formal | "Comproba con EXCEPT en ambos sentidos y conteos las 4 consultas" | Aceptado: 0 filas en los 4 EXCEPT y conteos iguales (3-3 ranking, 2-2 subconsulta) |

## Parte 4 - Competencia

| Herramienta | Para que se uso | Prompt / spec (resumen) | Se acepto / se descarto - por que |
|---|---|---|---|
| OpenCode | Optimizar la consulta comun de competencia | "Optimiza facturacion por usuario y categoria (4 tablas + agregacion); propone reescrituras e indices justificados en el plan real" | Aceptado: estrategia ANALYZE + indice ya justificado. Descartadas: forzar join order (el planificador ya los elige baratos con estadisticas reales), reescritura con subconsultas (cambia semantica y agrega costo), indice sobre fecha_pedido (sin nodo que lo justifique). Todo se registro, tambien lo que no funciono |

## Declaracion

Toda propuesta de la IA fue leida, entendida y contrastada contra el plan real antes de
aplicarse. Las que no se pudieron explicar se descartaron. Las mediciones se tomaron con
EXPLAIN (ANALYZE, BUFFERS) antes y despues de cada cambio sobre la base de trabajo.

## Salvedad de la base

La base disponible no estaba poblada masivamente (5 usuarios, 5 pedidos, 8 detalles, 15
productos); se registro la decision de continuar con esos datos y los tiempos deben
interpretarse con esa limitacion. La metodologia, los planes y la lectura critica son
validos; las mejoras en la base masiva requieren re-medicion.