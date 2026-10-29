--Creacion de una base de datos
create database replica_comercial;

-- Tipos enumerados
CREATE TYPE perfil          AS ENUM ('ADMIN','USUARIO');
CREATE TYPE situacion_compra AS ENUM ('PENDIENTE','CONFIRMADO',
                                      'TERMINADO','CANCELADO');
CREATE TYPE modalidad_pago  AS ENUM ('TARJETA','TRANSFERENCIA','EFECTIVO');

-- Creacion de tablas con distintas validaciones
CREATE TABLE rubro (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    eliminado   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE articulo (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo      VARCHAR(120)   NOT NULL,
    valor       NUMERIC(10,2)  NOT NULL CHECK (valor >= 0),
    descripcion VARCHAR(255),
    unidades    INTEGER        NOT NULL DEFAULT 0 CHECK (unidades >= 0),
    imagen      VARCHAR(255),
    activo      BOOLEAN        NOT NULL DEFAULT TRUE,
    rubro_id    BIGINT         NOT NULL REFERENCES rubro(id),
    eliminado   BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE TABLE cliente (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombres     VARCHAR(80)  NOT NULL,
    apellidos   VARCHAR(80)  NOT NULL,
    correo      VARCHAR(120) NOT NULL UNIQUE,
    telefono    VARCHAR(30),
    clave       VARCHAR(255) NOT NULL,
    perfil      perfil       NOT NULL DEFAULT 'USUARIO',
    eliminado   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE compra (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dia        DATE             NOT NULL DEFAULT CURRENT_DATE,
    situacion  situacion_compra NOT NULL DEFAULT 'PENDIENTE',
    monto      NUMERIC(12,2)    NOT NULL DEFAULT 0 CHECK (monto >= 0),
    modalidad  modalidad_pago   NOT NULL,
    cliente_id BIGINT           NOT NULL REFERENCES cliente(id),
    eliminado  BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ      NOT NULL DEFAULT now()
);

CREATE TABLE detalle_compra (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unidades       INTEGER       NOT NULL CHECK (unidades > 0),
    valor_unitario NUMERIC(10,2) NOT NULL CHECK (valor_unitario >= 0),
    parcial        NUMERIC(12,2) NOT NULL CHECK (parcial >= 0),
    compra_id      BIGINT        NOT NULL REFERENCES compra(id)
                                 ON DELETE RESTRICT,
    articulo_id    BIGINT        NOT NULL REFERENCES articulo(id),
    eliminado      BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (compra_id, articulo_id)
);

-- Creacion de indices
create index idx_articulo_rubro on articulo(rubro_id);
create index idx_compra_cliente on compra(cliente_id);
create index idx_detalle_compra on detalle_compra(compra_id);
create index idx_compra_situacion_dia on compra(situacion,dia);
create index idx_articulo_desc on articulo using GIN (to_tsvector('spanish', descripcion));
create index idx_detalle_articulo on detalle_compra(articulo_id);