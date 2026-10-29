# TP4 - Parte 2 - Lectura critica de un plan con varios JOIN interpretado por IA

## Contexto

Se tomo el plan BASELINE de Q1 (Parte 1), que tiene 3 nodos de join. Se le pidio a la IA
que lo explique en lenguaje natural, nodo por nodo, a partir del texto del plan
unicamente. A continuacion se reproduce la explicacion tal como la genero la IA y la
contrastacion contra el plan real.

## Explicacion generada por la IA (reproducida textual)

"El plan comienza leyendo las 4 tablas con un nested loop: primero detalle_pedido,
despues pedido, producto y categoria. Para cada fila de pedido busca en detalle_pedido.
Los tres joins son del tipo index nested loop. La tabla externa del join con pedido es
`pedido` y la interna `detalle_pedido`, de la cual se construye el hash. La consulta
termina agrupando por producto y mes en un HashAggregate. El costo estimado total, 84.89,
son los milisegundos que va a tardar la consulta en el servidor. Se estima que leyo 500
filas de pedido.".

## Contraste contra el plan real

| Afirmacion de la IA | Correcta? | Correccion / evidencia del plan real |
|---|---|---|
| "Los tres joins son index nested loop" | **No** | Los tres nodos de join son **Hash Join** (aparece literalmente "Hash Join ... Hash Cond"). No hay ningun Nested Loop en el plan. |
| "La tabla externa del join es pedido y la interna detalle_pedido (de la cual se construye el hash)" | **No** | En el nodo `Hash Join (dp.pedido_id = ped.id_pedido)` la tabla **externa es detalle_pedido** (`Seq Scan on detalle_pedido dp`) y la **interna es pedido**, sobre la que se construye el `Hash` (`Hash -> Seq Scan on pedido ped`). La IA invirtio externa/interna. |
| "El costo estimado total 84.89 son los milisegundos que tardara la consulta" | **No** | `cost=84.89` es una **unidad arbitraria del planificador** (cost=84.89..85.41 filas=210). El tiempo real de ejecucion fue **6.775 ms** (Execution Time). Confundir costo estimado con tiempo real es el error tipico que se pedia detectar. |
| "Se estima que leyo 500 filas de pedido" | **No** | 500 es la **estimacion por defecto** del planificador (las tablas no estaban analizadas, reltuples=-1). El `Seq Scan on pedido` leyo realmente **4 filas** (filtro `NOT eliminado` descarto 1). |
| "Agrupa por producto y mes en un HashAggregate" | **No** | El `HashAggregate` agrupa por **nombre_categoria y date_trunc('month', fecha_pedido)** (Group Key: `c.nombre_categoria`, `date_trunc(...)`). No participa id/nombre de producto en el grouping. |
| Un enlazamiento valido: la agregacion ocurre despues de completar los tres joins | **Si** | El nodo `HashAggregate` esta por encima de los 3 `Hash Join`; agrega el resultado combinado de las 4 tablas. Evidencia: indentacion del plan y `Group Key` sobre columnas de categoria/pedido. |

## Hallazgos que se documentan

- La IA fallo en los 3 puntos que la consigna pedia verificar con atencion: (1) tipos de
  join (Hash vs Nested Loop), (2) tabla externa/interna del join, y (3) costo estimado vs
  tiempo real. Tambien erro en el group key y en interpretar la estimacion de filas como
  valores reales.
- Leccion: las afirmaciones de la IA hay que contrastarlas SIEMPRE contra el texto del
  plan (indentacion, "Hash Cond", "Seq Scan on", filas estimadas vs actuales).

## Plan real usado como evidencia (Q1 baseline)

```
Sort  (cost=84.89..85.41 rows=210) (actual time=4.240..4.243 rows=7)
  => HashAggregate  (Group Key: c.nombre_categoria, date_trunc(...))
     => Hash Join   Hash Cond: (pr.categoria_id = c.id_categoria)
        => Hash Join   Hash Cond: (dp.producto_id = pr.id_producto)
           => Hash Join   Hash Cond: (dp.pedido_id = ped.id_pedido)
              => Seq Scan on detalle_pedido dp     (est 420 / real 7)
              => Hash -> Seq Scan on pedido ped    (est 500 / real 4)
           => Hash -> Seq Scan on producto pr      (est 50 / real 15)
        => Hash -> Seq Scan on categoria c         (est 110 / real 6)
Execution Time: 6.775 ms
```