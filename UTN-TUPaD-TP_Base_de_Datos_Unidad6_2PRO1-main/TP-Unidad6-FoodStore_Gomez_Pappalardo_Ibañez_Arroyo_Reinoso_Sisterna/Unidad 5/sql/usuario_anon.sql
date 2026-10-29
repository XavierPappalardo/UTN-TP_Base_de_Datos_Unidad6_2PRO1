-- =====================================================================
-- usuario_anon.sql — Food Store · TP Unidad 5, Parte D
-- Tabla anonimizada usuario_anon con datos sinteticos DETERMINISTAS
-- (patron Clase 2): cada fila anonimizada deriva 1:1 de la fila real.
-- Columnas de agrupacion (rol, created_at, eliminado) se copian VERBATIM
-- para que los agregados coincidan; columnas identificatorias se sintetizan
-- de forma determinista (mismo input -> mismo sintetico, unicidad de mails
-- preservada). JAMAS se copian contrasena_usuario ni celular_usuario.
-- Re-ejecutable. Ejecutar como postgres o admin_datos:
--   psql -h localhost -U postgres -d food_store -f usuario_anon.sql
-- =====================================================================

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id_usuario       BIGINT       PRIMARY KEY,
    nombre_usuario   VARCHAR(80)  NOT NULL,
    apellido_usuario VARCHAR(80)  NOT NULL,
    mail_usuario     VARCHAR(120) NOT NULL UNIQUE,
    rol              rol          NOT NULL,
    eliminado        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ  NOT NULL,
    -- NOTA: sin celular_usuario ni contrasena_usuario por diseno.
    origen_id        BIGINT       NOT NULL UNIQUE  -- trazabilidad 1:1 con usuario
);

INSERT INTO usuario_anon
    (id_usuario, nombre_usuario, apellido_usuario, mail_usuario,
     rol, eliminado, created_at, origen_id)
SELECT id_usuario,
       'Usuario_'  || id_usuario,                       -- sintetico determinista
       'Apellido_' || id_usuario,                       -- sintetico determinista
       'usuario_'  || id_usuario || '@ejemplo.local',  -- formato y unicidad preservados
       rol, eliminado, created_at, id_usuario
FROM usuario
ORDER BY id_usuario;

COMMENT ON TABLE usuario_anon IS
'Parte D: version anonimizada determinista de usuario. Segura para IA.';

-- Consulta de agregacion sobre usuario_anon (pedida a la IA con precision):
-- cantidad de usuarios por rol y por mes de alta.
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
FROM usuario_anon
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;

-- Equivalente sobre la tabla real (generada por la IA a partir de la anterior):
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
FROM usuario
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
