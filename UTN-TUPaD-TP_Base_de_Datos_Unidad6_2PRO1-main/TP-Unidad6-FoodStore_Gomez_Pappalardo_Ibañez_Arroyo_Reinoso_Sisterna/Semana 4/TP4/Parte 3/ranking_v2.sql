-- TP4 - Parte 3 (a) - Ranking de usuarios por gasto - v2 (estructura distinta)
-- Agregacion en CTE + ranking sin funcion de ventana: cada puesto se calcula contando
-- cuantos usuarios tienen gasto estrictamente mayor (+1). RANK comparte puesto en
-- empates y deja hueco despues; contar ">" reproduce exactamente esa semantica.
WITH gasto_usuario AS (
    SELECT u.id_usuario,
           u.nombre_usuario || ' ' || u.apellido_usuario AS nombre_completo,
           SUM(p.total_pedido)                           AS total_gastado
    FROM   usuario u
    JOIN   pedido p ON p.usuario_id = u.id_usuario AND p.eliminado = FALSE
    WHERE  u.eliminado = FALSE
    GROUP  BY u.id_usuario, u.nombre_usuario, u.apellido_usuario
)
SELECT gu.id_usuario,
       gu.nombre_completo,
       gu.total_gastado,
       (SELECT COUNT(*) + 1
        FROM   gasto_usuario gg
        WHERE  gg.total_gastado > gu.total_gastado) AS puesto
FROM   gasto_usuario gu;