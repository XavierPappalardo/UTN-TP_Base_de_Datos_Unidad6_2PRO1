-- =====================================================================
-- auditoria_test.sql — Food Store · TP Unidad 5, Parte B
-- Secuencia breve de operaciones de prueba para el log de auditoria:
--   1 lectura + 1 insercion + 1 actualizacion (+ limpieza) y, desde shell,
--   1 intento de inicio de sesion fallido (ver docs/informe_auditoria.md).
-- Ejecutar como superusuario conectado a food_store:
--   psql -h localhost -U postgres -d food_store -f auditoria_test.sql
-- Requiere: log_connections=on, log_disconnections=on, log_statement='mod'.
-- El marcador /* TP-U5-PARTE-B */ permite localizar el fragmento en el log.
-- =====================================================================

\echo '--- TP-U5-PARTE-B inicio ---'

-- 1. LECTURA (con log_statement='mod' el SELECT no queda como statement;
--    la conexion que lo emite si queda registrada: ver informe punto 3).
SELECT /* TP-U5-PARTE-B lectura */
    id_producto, nombre_producto, precio_producto
FROM producto
ORDER BY id_producto
LIMIT 3;

-- 2. INSERCION (categoria de prueba; queda registrada como statement mod).
INSERT INTO categoria (nombre_categoria, descripcion_categoria)
VALUES ('__TP_U5_AUDIT__', 'categoria de prueba de auditoria TP-U5-PARTE-B')
RETURNING id_categoria;

-- 3. ACTUALIZACION (sube y revierte stock: dos statements mod).
UPDATE producto SET stock_producto = stock_producto + 1
WHERE id_producto = 1;  -- TP-U5-PARTE-B
UPDATE producto SET stock_producto = stock_producto - 1
WHERE id_producto = 1;  -- TP-U5-PARTE-B

-- Limpieza: el trigger fn_soft_delete convierte este DELETE en UPDATE
-- de eliminado=TRUE (igual queda el statement en el log).
DELETE FROM categoria WHERE nombre_categoria = '__TP_U5_AUDIT__';  -- TP-U5-PARTE-B

\echo '--- TP-U5-PARTE-B fin ---'

-- 4. INICIO DE SESION FALLIDO (NO corre dentro de esta sesion: ejecutar en
--    shell APARTE, inmediatamente despues, para que quede junto en el log):
--    $env:PGPASSWORD="clave_incorrecta"
--    psql -h localhost -U app_web -d food_store -c "SELECT 1"
--    Resultado esperado: FATAL password authentication failed, registrado
--    en el log como conexion fallida (ver docs/log_auditoria_prueba.txt).
