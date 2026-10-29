-- =====================================================================
-- roles.sql — Food Store · TP Unidad 5, Parte A
-- Esquema de roles y permisos con principio de minimo privilegio.
-- Motor: PostgreSQL 16. Base: food_store. Ejecutar como superusuario
-- (postgres) conectado a food_store:
--   psql -h localhost -U postgres -d food_store -f roles.sql
-- Idempotente: puede re-ejecutarse (DROP IF EXISTS al inicio).
-- Diseno: docs/kiro_roles_spec/{requirements,design}.md
-- Grupo E: Gomez, Pappalardo, Reinoso, Ibanez, Sisterna, Arroyo (2026-10-15)
-- NOTA: passwords de desarrollo, NO usar en produccion.
-- =====================================================================

-- ---------------------------------------------------------------------
-- S0. Limpieza previa (orden inverso de dependencias)
-- ---------------------------------------------------------------------
RESET ROLE;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Limpieza idempotente en 3 FASES (el orden importa):
--   Fase 1: revocar privilegios sobre objetos existentes (tablas, secuencias,
--           funciones Y procedures: ALL FUNCTIONS no cubre sp_crear_pedido).
--   Fase 2: revocar ALTER DEFAULT PRIVILEGES (destinatario en pg_default_acl).
--   Fase 3: recien ahi, DROP de los roles.
-- Las fases van separadas porque los REVOKE ... FOR ROLE admin_datos exigen
-- que admin_datos aun exista, y los DROP exigen que no quede ningun grant.
-- Leccion aprendida: JAMAS DELETE directo sobre pg_default_acl (deja
-- dependencias huerfanas en pg_shdepend y corrompe los DROP siguientes).
DO $$
DECLARE r TEXT;
BEGIN
    -- Fase 1: objetos existentes.
    FOREACH r IN ARRAY ARRAY['app_web','admin_datos','usr_soporte',
        'usr_reportes','usr_lectura','rol_app_escritura','rol_app_lectura',
        'rol_soporte','rol_reportes','rol_auditor'] LOOP
        BEGIN EXECUTE format('REVOKE ALL ON DATABASE food_store FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
        BEGIN EXECUTE format('REVOKE ALL ON SCHEMA public FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
        BEGIN EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
        BEGIN EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
        BEGIN EXECUTE format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
        BEGIN EXECUTE format('REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM %I', r);
        EXCEPTION WHEN undefined_object THEN NULL; END;
    END LOOP;
    -- Fase 2a: defaults cuyo dueno es postgres (siempre existe).
    FOREACH r IN ARRAY ARRAY['app_web','admin_datos','usr_soporte',
        'usr_reportes','usr_lectura','rol_app_escritura','rol_app_lectura',
        'rol_soporte','rol_reportes','rol_auditor'] LOOP
        BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM %I', r);
        EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', r);
        EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %I', r);
        EXCEPTION WHEN OTHERS THEN NULL; END;
    END LOOP;
    -- Fase 2b: defaults cuyo dueno es admin_datos (solo si aun existe).
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        FOREACH r IN ARRAY ARRAY['app_web','admin_datos','usr_soporte',
            'usr_reportes','usr_lectura','rol_app_escritura','rol_app_lectura',
            'rol_soporte','rol_reportes','rol_auditor'] LOOP
            BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public REVOKE ALL ON TABLES FROM %I', r);
            EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', r);
            EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %I', r);
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;
    END IF;
    -- Fase 3: drops (IF EXISTS: en 1ra corrida no hay nada que borrar).
    FOREACH r IN ARRAY ARRAY['app_web','admin_datos','usr_soporte',
        'usr_reportes','usr_lectura','rol_app_escritura','rol_app_lectura',
        'rol_soporte','rol_reportes','rol_auditor'] LOOP
        EXECUTE format('DROP ROLE IF EXISTS %I', r);
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------
-- S0-bis. Reconstruccion previa obligatoria (Clase 1 y 2)
-- El repo clonado NO contenia roles.sql ni fn_autenticar /
-- fn_resetear_password (verificado 2026-10-15 por busqueda exhaustiva).
-- Se reconstruyen aqui como paso previo a la Parte A, con constancia
-- en BITACORA.md. Las funciones se definen en S4; los roles, debajo.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- S1. Roles de grupo (NOLOGIN) + rol adicional rol_auditor
-- ---------------------------------------------------------------------
CREATE ROLE rol_app_lectura  NOLOGIN;  -- lectura app: catalogo y pedidos, sin secretos
CREATE ROLE rol_app_escritura NOLOGIN;  -- checkout: inserta pedidos, descuenta stock
CREATE ROLE rol_soporte      NOLOGIN;  -- mesa de ayuda: ve pedidos, cambia estado
CREATE ROLE rol_reportes     NOLOGIN;  -- BI: solo lectura agregada, sin secretos
CREATE ROLE rol_auditor      NOLOGIN;  -- ADICIONAL del equipo: solo-lectura para rendicion de cuentas

-- ---------------------------------------------------------------------
-- S2. Roles de login (+ 3 usuarios de prueba de minimo privilegio)
-- ---------------------------------------------------------------------
CREATE ROLE app_web     LOGIN PASSWORD 'AppWeb_2026*'     CONNECTION LIMIT 50;
CREATE ROLE admin_datos LOGIN PASSWORD 'AdminDatos_2026*' CONNECTION LIMIT 5 CREATEROLE;
-- Usuarios de prueba (solo para verificacion y simulacro; sin poder admin):
CREATE ROLE usr_lectura  LOGIN PASSWORD 'Lec_2026*'  CONNECTION LIMIT 5;
CREATE ROLE usr_soporte  LOGIN PASSWORD 'Sop_2026*'  CONNECTION LIMIT 5;
CREATE ROLE usr_reportes LOGIN PASSWORD 'Rep_2026*'  CONNECTION LIMIT 5;

-- Herencia: escritura hereda lectura; cada login entra a su grupo.
GRANT rol_app_lectura  TO rol_app_escritura;
GRANT rol_app_escritura TO app_web;
GRANT rol_app_lectura  TO usr_lectura;
GRANT rol_soporte       TO usr_soporte;
GRANT rol_reportes      TO usr_reportes;
-- admin_datos NO hereda roles de app: sus permisos son explicitos (S3.6),
-- para que revocar algo en app nunca degrade la administracion.

-- ---------------------------------------------------------------------
-- S3. Permisos sobre la base food_store
-- ---------------------------------------------------------------------

-- S3.0 Acceso basico: todos necesitan CONNECT + USAGE en public.
GRANT CONNECT ON DATABASE food_store TO rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, rol_auditor, app_web, admin_datos,
    usr_lectura, usr_soporte, usr_reportes;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, rol_auditor, app_web, admin_datos,
    usr_lectura, usr_soporte, usr_reportes;
-- Nadie mas puede crear objetos ni conectarse sin autorizacion:
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE food_store FROM PUBLIC;

-- S3.1 Higiene: quitar todo lo heredado de PUBLIC sobre objetos existentes.
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- S3.2 Lectura general (tablas no sensibles + vistas).
-- Las vistas v_* ya excluyen eliminado=TRUE y no exponen contrasenas.
GRANT SELECT ON categoria, producto, pedido, detalle_pedido TO
    rol_app_lectura, rol_soporte, rol_reportes, rol_auditor;
GRANT SELECT ON
    v_categorias_vigentes, v_productos_vigentes,
    v_pedidos_resumen, v_pedido_detalle TO
    rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor;
-- rol_app_escritura hereda el SELECT via rol_app_lectura; el GRANT directo
-- en vistas es intencional (las vistas pueden recrearse y perder herencia).

-- S3.3 Permiso A NIVEL DE COLUMNA sobre usuario (requisito del TP).
-- Nadie de app/reportes/soporte/auditoria lee contrasena_usuario.
-- Lectura base (sin mail / celular / contrasena):
GRANT SELECT (id_usuario, nombre_usuario, apellido_usuario, rol,
              eliminado, created_at)
    ON usuario TO rol_app_lectura, rol_reportes, rol_auditor;
-- Soporte necesita contactar al cliente: suma mail y celular, NUNCA el hash:
GRANT SELECT (id_usuario, nombre_usuario, apellido_usuario, mail_usuario,
              celular_usuario, rol, eliminado, created_at)
    ON usuario TO rol_soporte;
-- rol_app_escritura hereda las columnas de rol_app_lectura (sin secretos).
-- Solo admin_datos (y el dueno postgres) ven usuario completa:
-- (no se otorga ningun GRANT sobre usuario a otros roles).

-- S3.4 Escritura acotada de rol_app_escritura (checkout).
GRANT INSERT ON pedido, detalle_pedido TO rol_app_escritura;
-- UPDATE solo en columnas puntuales (permiso de columna, segundo caso):
GRANT UPDATE (estado_pedido, total_pedido) ON pedido TO rol_app_escritura;
GRANT UPDATE (cantidad_detallepedido, precio_unitario, subtotal_detallepedido)
    ON detalle_pedido TO rol_app_escritura;
GRANT UPDATE (stock_producto) ON producto TO rol_app_escritura;
-- INSERT necesita consumir las secuencias de las PK identity:
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;

-- S3.5 Soporte: solo puede mover el estado del pedido (reclamos/cancelaciones).
GRANT UPDATE (estado_pedido) ON pedido TO rol_soporte;
-- Sin INSERT ni DELETE: soporte no crea pedidos ni borra nada.

-- S3.6 admin_datos: administracion funcional completa (sin SUPERUSER).
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;
GRANT USAGE, CREATE ON SCHEMA public TO admin_datos;

-- S3.7 Prohibicion explicita de borrado fisico (coherente con fn_soft_delete:
-- el borrado es logico via eliminado=TRUE, que se hace con UPDATE).
REVOKE DELETE ON ALL TABLES IN SCHEMA public
    FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor;
-- (admin_datos conserva DELETE solo para correcciones excepcionales.)

-- ---------------------------------------------------------------------
-- S4. Funciones de autenticacion (reconstruccion Clase 2) y EXECUTE
-- ---------------------------------------------------------------------

-- fn_autenticar: devuelve TRUE si mail+hash coinciden y el usuario esta
-- vigente. SECURITY DEFINER para validar sin otorgar SELECT sobre secretos.
-- En desarrollo compara texto simple (datos 'hash_*'); en produccion usar
-- crypt() de pgcrypto. No revela si el mail existe (FALSE en ambos fallos).
CREATE OR REPLACE FUNCTION fn_autenticar(p_mail TEXT, p_pass TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok BOOLEAN := FALSE;
BEGIN
    SELECT (contrasena_usuario = p_pass) INTO v_ok
    FROM usuario
    WHERE mail_usuario = p_mail AND eliminado = FALSE;
    RETURN COALESCE(v_ok, FALSE);
END;
$$;
COMMENT ON FUNCTION fn_autenticar(TEXT, TEXT) IS
'Clase 2 reconstruida: autentica sin exponer hashes. SECURITY DEFINER.';

-- fn_resetear_password: rota el hash. Operacion RESERVADA a admin_datos.
CREATE OR REPLACE FUNCTION fn_resetear_password(p_mail TEXT, p_nuevo_hash TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF p_nuevo_hash IS NULL OR length(p_nuevo_hash) < 8 THEN
        RAISE EXCEPTION 'fn_resetear_password: hash nuevo demasiado corto';
    END IF;
    UPDATE usuario SET contrasena_usuario = p_nuevo_hash
    WHERE mail_usuario = p_mail AND eliminado = FALSE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_resetear_password: usuario % inexistente o eliminado', p_mail;
    END IF;
END;
$$;
COMMENT ON FUNCTION fn_resetear_password(TEXT, TEXT) IS
'Clase 2 reconstruida: solo ejecutable por admin_datos. SECURITY DEFINER.';

REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_resetear_password(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO
    rol_app_lectura, rol_app_escritura, rol_soporte;
GRANT EXECUTE ON FUNCTION fn_resetear_password(TEXT, TEXT) TO admin_datos;

-- Rutinas de negocio: checkout (PROCEDURE) y calculos (FUNCTION).
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION calcular_total_pedido(BIGINT) TO
    rol_app_escritura, rol_reportes, rol_auditor;

-- ---------------------------------------------------------------------
-- S5. Tablas FUTURAS heredan la misma politica (requisito del TP)
-- ---------------------------------------------------------------------
-- Todo objeto creado por postgres o admin_datos nace ya con la lectura
-- otorgada (y sin escritura salvo el ambito de rol_app_escritura).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura, rol_soporte, rol_reportes, rol_auditor;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres, admin_datos IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO rol_app_lectura, rol_app_escritura;
-- Y admin_datos mantiene control total sobre lo futuro:
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON SEQUENCES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON FUNCTIONS TO admin_datos;

-- ---------------------------------------------------------------------
-- S6. Verificacion sugerida (salida a adjuntar en docs/verificacion_roles.txt)
--   \du
--   SELECT grantee, table_name, privilege_type
--     FROM information_schema.role_table_grants
--     WHERE table_schema='public' AND grantee LIKE 'rol\_%' OR grantee IN
--       ('app_web','admin_datos','usr_lectura','usr_soporte','usr_reportes')
--     ORDER BY grantee, table_name, privilege_type;
-- Pruebas negativas (deben fallar con permission denied):
--   SET SESSION AUTHORIZATION usr_reportes; INSERT INTO pedido ...;  -- falla
--   SET SESSION AUTHORIZATION usr_lectura; SELECT contrasena_usuario FROM usuario; -- falla
--   SET SESSION AUTHORIZATION app_web; GRANT admin_datos TO app_web; -- falla
-- =====================================================================
