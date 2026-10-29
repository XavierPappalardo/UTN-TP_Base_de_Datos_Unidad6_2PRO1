-- =====================================================================
-- simulacro_incidente.sql — Food Store · TP Unidad 5, Parte C
-- SIMULACRO CONTROLADO de incidente de acceso indebido.
-- Ejecutar EXCLUSIVAMENTE contra la instancia propia de desarrollo
-- (food_store local). JAMAS contra sistemas de terceros.
-- Como superusuario NO: este script corre como app_web (credencial de la
-- app, simulando su compromiso), salvo el paso 0 de preparacion.
--   $env:PGPASSWORD="AppWeb_2026*"
--   psql -h localhost -U app_web -d food_store -f simulacro_incidente.sql
-- Requiere visibilidad total durante el laboratorio:
--   ALTER DATABASE food_store SET log_statement='all';  -- solo el lab
-- Al terminar, revertir con ALTER DATABASE food_store RESET log_statement;
-- El marcador /* TP-U5-SIMULACRO */ permite extraer el fragmento del log.
-- Los pasos SIM-4 y SIM-5 DEBEN fallar (constancia en informe_incidente.md);
-- por eso el script corre SIN ON_ERROR_STOP: un ERROR esperado no aborta.
-- =====================================================================

\echo '=== TP-U5-SIMULACRO inicio (solo entorno propio de desarrollo) ==='

-- SIM-1: varios intentos fallidos contra fn_autenticar (fuerza bruta).
\echo '--- SIM-1: 4 intentos fallidos de inicio de sesion ---'
SELECT /* TP-U5-SIMULACRO fuerza-1 */ fn_autenticar('juan@x.com', 'clave_errada_1');
SELECT /* TP-U5-SIMULACRO fuerza-2 */ fn_autenticar('juan@x.com', 'clave_errada_2');
SELECT /* TP-U5-SIMULACRO fuerza-3 */ fn_autenticar('juan@x.com', 'Password123');
SELECT /* TP-U5-SIMULACRO fuerza-4 */ fn_autenticar('juan@x.com', 'juan12345');

-- SIM-2: inicio de sesion exitoso (credencial comprometida adivinada).
\echo '--- SIM-2: 1 inicio de sesion exitoso ---'
SELECT /* TP-U5-SIMULACRO login-ok */ fn_autenticar('juan@x.com', 'hash_juan');

-- SIM-3: lectura masiva de la tabla usuario con la credencial comprometida.
-- NOTA de minimo privilegio: app_web solo ve columnas no sensibles (hereda
-- de rol_app_lectura); ni mail, ni celular, ni contrasena. El barrido expone
-- igual PII (nombres + roles), pero el blast radius esta acotado por el
-- permiso a nivel de columna de la Parte A.
\echo '--- SIM-3: lectura masiva de usuario ---'
SELECT /* TP-U5-SIMULACRO barrido */ count(*) AS total_usuarios FROM usuario;
SELECT /* TP-U5-SIMULACRO barrido */ id_usuario, nombre_usuario,
    apellido_usuario, rol, eliminado, created_at
FROM usuario
ORDER BY id_usuario;

-- SIM-4: intento de escalamiento — membresia en admin_datos (DEBE FALLAR).
\echo '--- SIM-4: intento de escalamiento (falla esperada) ---'
GRANT admin_datos TO app_web;  -- TP-U5-SIMULACRO escalamiento

-- SIM-5: operacion reservada a admin_datos (DEBE FALLAR).
\echo '--- SIM-5: reseteo de password ajeno (falla esperada) ---'
SELECT /* TP-U5-SIMULACRO reservada */ fn_resetear_password('ana@x.com', 'hash_atacante_99');

\echo '=== TP-U5-SIMULACRO fin ==='
