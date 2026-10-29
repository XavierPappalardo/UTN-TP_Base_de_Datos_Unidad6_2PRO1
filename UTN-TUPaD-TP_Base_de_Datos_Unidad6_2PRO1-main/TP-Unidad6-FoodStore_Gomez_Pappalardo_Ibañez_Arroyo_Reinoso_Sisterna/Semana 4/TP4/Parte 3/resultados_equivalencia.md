# TP4 - Parte 3 - Resultados de equivalencia

## (a) Ranking de usuarios por gasto

Especificacion:
> Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada usuario
> vigente con al menos un pedido vigente, su nombre completo, el total gastado (suma de
> pedido.total en pedidos no eliminados) y su puesto en un ranking de mayor a menor gasto,
> sin colapsar filas. En caso de empate, deben compartir el mismo puesto. No uses SELECT *.

- v1: `RANK() OVER (ORDER BY SUM(total_pedido) DESC)` directo sobre la agregacion.
- v2: agregacion en CTE + ranking sin funcion de ventana (subconsulta que cuenta
  competidores con gasto estrictamente mayor + 1). REPRODUCE la semantica exacta de
  RANK (puesto compartido en empates y hueco posterior).

Resultado real (base actual):
| id_usuario | nombre_completo | total_gastado | puesto |
|---|---|---|---|
| 2 | Juan Pérez | 17300.00 | 1 |
| 3 | Ana Garis | 7300.00 | 2 |
| 4 | Bruno Ledesma | 4800.00 | 3 |

Verificacion:
```
rank v1 EXCEPT v2 -> 0 filas
rank v2 EXCEPT v1 -> 0 filas
rank conteo v1    -> 3
rank conteo v2    -> 3
```

## (b) Subconsulta correlacionada: productos por encima del promedio de su categoria

Especificacion:
> Genera una consulta SQL sobre el esquema de Food Store que devuelva los productos
> vigentes cuya recaudacion total (suma de subtotal de detalles no eliminados, dentro de
> pedidos no eliminados) supera el promedio de recaudacion de los productos de su misma
> categoria. Incluir nombre del producto, categoria y recaudacion. No uses SELECT *.

- v1: subconsulta correlacionada (HAVING > AVG de la categoria del producto externo).
- v2: funciones de ventana (`AVG() OVER (PARTITION BY categoria_id)` sobre la
  recaudacion por producto) y filtro `> promedio_categoria`.

### Bug detectado por la verificacion (caso "parecen equivalentes pero no lo son")

La primera version de v1 daba **0 filas**, mientras v2 daba **2 filas**:

| id_producto | nombre_producto | categoria | recaudacion |
|---|---|---|---|
| 1 | Muzzarella | Pizzas | 9000.00 |
| 11 | Cerveza artesanal IPA | Bebidas | 3600.00 |

Causa raiz: en el subquery correlacionado se agrupo por `categoria_id` solamente, de modo
que `pc` tenia **una fila por categoria con el TOTAL de la categoria**, y `AVG(pc.recau)`
devolvia el total de la categoria entera (ej. Pizzas total = 19000). Ningun producto
superaba ese total, por eso 0 filas. La comparacion correcta exige el **promedio por
producto dentro de la categoria**: `GROUP BY (categoria_id, id_producto)` en el subquery.

Este es exactamente el tipo de falla que la practica busca: un JOIN dentro de la
subconsulta sumaba filas y cambiaba la escala de la comparacion sin que ambas consultas
"se notaran" distintas.

### Despues de corregir v1 (se agrego id_producto al GROUP BY del subquery)

```
sub v1 EXCEPT v2 -> 0 filas
sub v2 EXCEPT v1 -> 0 filas
sub conteo v1    -> 2
sub conteo v2    -> 2
```

Ambas versiones devuelven Muzzarella (9000.00) y Cerveza artesanal IPA (3600.00).

Conclusion: las cuatro consultas (2 de ranking y 2 de subconsulta) quedaron verificadas
como formalmente equivalentes mediante EXCEPT en ambos sentidos y conteos coincidentes.