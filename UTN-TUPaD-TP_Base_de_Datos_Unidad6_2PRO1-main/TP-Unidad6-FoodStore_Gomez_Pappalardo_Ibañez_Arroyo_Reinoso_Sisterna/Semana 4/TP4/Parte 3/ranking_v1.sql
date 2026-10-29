-- TP4 - Parte 3 (a) - Ranking de usuarios por gasto - v1 (funcion de ventana)
-- Spec: "Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada
--  usuario vigente con al menos un pedido vigente, su nombre completo, el total gastado
--  (suma de pedido.total en pedidos no eliminados) y su puesto en un ranking de mayor a
--  menor gasto, sin colapsar filas. En caso de empate, deben compartir el mismo puesto.
--  No uses SELECT *."
SELECT u.id_usuario,
       u.nombre_usuario || ' ' || u.apellido_usuario AS nombre_completo,
       SUM(p.total_pedido)                            AS total_gastado,
       RANK() OVER (ORDER BY SUM(p.total_pedido) DESC) AS puesto
FROM   usuario u
JOIN   pedido p ON p.usuario_id = u.id_usuario AND p.eliminado = FALSE
WHERE  u.eliminado = FALSE
GROUP  BY u.id_usuario, u.nombre_usuario, u.apellido_usuario;