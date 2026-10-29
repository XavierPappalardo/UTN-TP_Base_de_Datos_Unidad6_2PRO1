# spec: vista_02_pedidos_usuarios_segura

Objetivo: reporte "pedidos con los datos del usuario" con criterio de SEGURIDAD.
Columnas a exponer: ped.id_pedido, ped.fecha_pedido, ped.estado_pedido,
ped.total_pedido, ped.forma_pago, u.id_usuario, u.nombre_usuario,
u.apellido_usuario, u.mail_usuario.
Columna a OCULTAR: u.contrasena_usuario (y u.celular_usuario): no se exponen.
Filtro de vigencia: ped.eliminado = FALSE AND u.eliminado = FALSE.
Criterio de aceptación: (1) la vista no contiene contrasena_usuario
(information_schema lo confirma); (2) equivalencia exacta con la consulta manual
vía EXCEPT; (3) se puede otorgar SELECT sobre la vista sin dar acceso a usuario.
