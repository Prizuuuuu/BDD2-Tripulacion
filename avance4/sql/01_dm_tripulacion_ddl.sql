-- =====================================================================
-- Avance 4 · Grupo 5 · Subsistema Tripulación
-- Data Mart dm_tripulacion en MySQL 8.0 (motor opuesto a la Unidad 1)
-- Esquema de CONSTELACIÓN: 3 tablas de hechos que comparten dimensiones
-- =====================================================================
DROP DATABASE IF EXISTS dm_tripulacion;
CREATE DATABASE dm_tripulacion CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE dm_tripulacion;

-- ---------------------------------------------------------------------
-- Dimensiones (claves sustitutas SK; la clave natural se guarda para trazabilidad)
-- ---------------------------------------------------------------------
CREATE TABLE dim_tiempo (
  sk_tiempo      INT          NOT NULL PRIMARY KEY,      -- AAAAMMDD
  fecha          DATE         NOT NULL UNIQUE,
  anio           SMALLINT     NOT NULL,
  trimestre      TINYINT      NOT NULL,
  mes            TINYINT      NOT NULL,
  nombre_mes     VARCHAR(10)  NOT NULL,
  anio_mes       CHAR(7)      NOT NULL,
  semana_iso     TINYINT      NOT NULL,
  dia_semana     TINYINT      NOT NULL,
  nombre_dia     VARCHAR(10)  NOT NULL,
  es_fin_semana  TINYINT(1)   NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_region (
  sk_region      SMALLINT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_region      SMALLINT     NOT NULL UNIQUE,           -- clave natural (staging.region)
  nombre_region  VARCHAR(10)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_aeropuerto (
  sk_aeropuerto  SMALLINT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_aeropuerto  INT          NOT NULL UNIQUE,           -- clave natural (staging.aeropuerto)
  codigo_iata    CHAR(3)      NOT NULL UNIQUE,
  nombre         VARCHAR(100) NOT NULL,
  ciudad         VARCHAR(60)  NOT NULL,
  estado         CHAR(2)      NOT NULL,
  es_hub         TINYINT(1)   NOT NULL,
  id_region      SMALLINT     NOT NULL,
  sk_region      SMALLINT     NULL,
  region         VARCHAR(10)  NULL,
  CONSTRAINT fk_aerop_region FOREIGN KEY (sk_region) REFERENCES dim_region(sk_region)
) ENGINE=InnoDB;

CREATE TABLE dim_tripulante (
  sk_tripulante      INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_tripulante      BIGINT       NOT NULL UNIQUE,       -- clave natural (staging.tripulante)
  numero_empleado    CHAR(8)      NOT NULL,
  nombre_completo    VARCHAR(101) NOT NULL,
  cargo              VARCHAR(20)  NOT NULL,
  grupo              VARCHAR(20)  NOT NULL,
  estado             VARCHAR(10)  NOT NULL,
  fecha_ingreso      DATE         NOT NULL,
  anios_antiguedad   TINYINT      NOT NULL,
  rango_antiguedad   VARCHAR(10)  NOT NULL,
  base_iata          CHAR(3)      NOT NULL,
  base_ciudad        VARCHAR(60)  NOT NULL,
  base_region        VARCHAR(10)  NOT NULL,
  sk_aeropuerto_base SMALLINT     NULL,
  sk_region_base     SMALLINT     NULL,
  CONSTRAINT fk_trip_base   FOREIGN KEY (sk_aeropuerto_base) REFERENCES dim_aeropuerto(sk_aeropuerto),
  CONSTRAINT fk_trip_region FOREIGN KEY (sk_region_base)     REFERENCES dim_region(sk_region)
) ENGINE=InnoDB;

CREATE TABLE dim_vuelo (
  sk_vuelo       INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_vuelo       BIGINT       NOT NULL UNIQUE,           -- clave natural (staging.vuelo y nodo :Vuelo)
  numero_vuelo   CHAR(6)      NOT NULL,
  ruta           CHAR(7)      NOT NULL,
  equipo         VARCHAR(10)  NULL,                      -- viene de Neo4j (v.equipo)
  duracion_h     DECIMAL(5,2) NOT NULL,
  estado_vuelo   VARCHAR(12)  NOT NULL,
  franja_salida  VARCHAR(10)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_credencial (
  sk_credencial  SMALLINT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fuente         VARCHAR(20)  NOT NULL,                  -- PostgreSQL (U1) o Neo4j (U3)
  categoria      VARCHAR(25)  NOT NULL,
  tipo           VARCHAR(30)  NOT NULL,
  equipo         VARCHAR(10)  NULL,
  UNIQUE KEY uq_credencial (fuente, tipo, equipo)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Hechos
-- ---------------------------------------------------------------------
-- Grano: una fila por tripulante asignado a un tramo de vuelo (una asignación)
CREATE TABLE fact_asignacion (
  sk_tiempo                  INT          NOT NULL,
  sk_tripulante              INT          NOT NULL,
  sk_vuelo                   INT          NOT NULL,
  sk_aeropuerto_origen       SMALLINT     NOT NULL,
  sk_aeropuerto_destino      SMALLINT     NOT NULL,
  sk_region_origen           SMALLINT     NOT NULL,
  id_asignacion              BIGINT       NOT NULL PRIMARY KEY,   -- degenerada (trazabilidad)
  id_pairing                 VARCHAR(20)  NULL,                   -- degenerada (Neo4j)
  orden_en_pairing           TINYINT      NULL,
  rol                        VARCHAR(20)  NOT NULL,
  horas_vuelo                DECIMAL(5,2) NOT NULL,
  retraso_minutos            SMALLINT     NOT NULL,
  vuelo_puntual              TINYINT(1)   NOT NULL,
  descanso_previo_h          DECIMAL(7,1) NULL,
  requirio_reposicionamiento TINYINT(1)   NULL,
  fuera_region_base          TINYINT(1)   NOT NULL,
  es_reemplazo               TINYINT(1)   NOT NULL,
  reemplazo_ultima_hora      TINYINT(1)   NOT NULL,
  aviso_horas                TINYINT      NULL,
  motivo_reemplazo           VARCHAR(30)  NULL,
  CONSTRAINT fk_fa_tiempo  FOREIGN KEY (sk_tiempo)             REFERENCES dim_tiempo(sk_tiempo),
  CONSTRAINT fk_fa_trip    FOREIGN KEY (sk_tripulante)         REFERENCES dim_tripulante(sk_tripulante),
  CONSTRAINT fk_fa_vuelo   FOREIGN KEY (sk_vuelo)              REFERENCES dim_vuelo(sk_vuelo),
  CONSTRAINT fk_fa_origen  FOREIGN KEY (sk_aeropuerto_origen)  REFERENCES dim_aeropuerto(sk_aeropuerto),
  CONSTRAINT fk_fa_destino FOREIGN KEY (sk_aeropuerto_destino) REFERENCES dim_aeropuerto(sk_aeropuerto),
  CONSTRAINT fk_fa_region  FOREIGN KEY (sk_region_origen)      REFERENCES dim_region(sk_region)
) ENGINE=InnoDB;

-- Grano: una fila por jornada laboral de un tripulante en un día
CREATE TABLE fact_jornada (
  sk_tiempo             INT          NOT NULL,
  sk_tripulante         INT          NOT NULL,
  sk_aeropuerto_base    SMALLINT     NOT NULL,
  sk_region_base        SMALLINT     NOT NULL,
  id_jornada            BIGINT       NOT NULL PRIMARY KEY,         -- degenerada
  tipo_jornada          VARCHAR(15)  NOT NULL,
  horas_servicio        DECIMAL(4,2) NOT NULL,
  tramos_volados        TINYINT      NOT NULL,
  horas_vuelo_dia       DECIMAL(5,2) NOT NULL,
  descanso_previo_h     DECIMAL(7,2) NULL,
  horas_servicio_7d     DECIMAL(6,2) NOT NULL,
  margen_60h_semana     DECIMAL(6,2) NOT NULL,
  cumple_jornada_13h    TINYINT(1)   NOT NULL,
  cumple_descanso_10h   TINYINT(1)   NOT NULL,
  cumple_60h_semana     TINYINT(1)   NOT NULL,
  cumple_jornada_maxima TINYINT(1)   NOT NULL,
  CONSTRAINT fk_fj_tiempo FOREIGN KEY (sk_tiempo)          REFERENCES dim_tiempo(sk_tiempo),
  CONSTRAINT fk_fj_trip   FOREIGN KEY (sk_tripulante)      REFERENCES dim_tripulante(sk_tripulante),
  CONSTRAINT fk_fj_base   FOREIGN KEY (sk_aeropuerto_base) REFERENCES dim_aeropuerto(sk_aeropuerto),
  CONSTRAINT fk_fj_region FOREIGN KEY (sk_region_base)     REFERENCES dim_region(sk_region)
) ENGINE=InnoDB;

-- Grano: una fila por certificación (U1) o habilitación de equipo (U3) de un tripulante, foto al 30/06/2026
CREATE TABLE fact_credencial (
  sk_tiempo_corte        INT          NOT NULL,
  sk_tiempo_vencimiento  INT          NULL,
  sk_tripulante          INT          NOT NULL,
  sk_credencial          SMALLINT     NOT NULL,
  sk_aeropuerto_base     SMALLINT     NOT NULL,
  sk_region_base         SMALLINT     NOT NULL,
  id_credencial          VARCHAR(25)  NOT NULL PRIMARY KEY,      -- C-<id_certificacion> o id_habilitacion
  estado                 VARCHAR(20)  NOT NULL,
  dias_para_vencer       INT          NULL,
  proxima_a_vencer_90d   TINYINT(1)   NOT NULL,
  vencida                TINYINT(1)   NOT NULL,
  CONSTRAINT fk_fc_corte  FOREIGN KEY (sk_tiempo_corte)       REFERENCES dim_tiempo(sk_tiempo),
  CONSTRAINT fk_fc_venc   FOREIGN KEY (sk_tiempo_vencimiento) REFERENCES dim_tiempo(sk_tiempo),
  CONSTRAINT fk_fc_trip   FOREIGN KEY (sk_tripulante)         REFERENCES dim_tripulante(sk_tripulante),
  CONSTRAINT fk_fc_cred   FOREIGN KEY (sk_credencial)         REFERENCES dim_credencial(sk_credencial),
  CONSTRAINT fk_fc_base   FOREIGN KEY (sk_aeropuerto_base)    REFERENCES dim_aeropuerto(sk_aeropuerto),
  CONSTRAINT fk_fc_region FOREIGN KEY (sk_region_base)        REFERENCES dim_region(sk_region)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tablas de paso (stg_) que llena Spoon con claves naturales; el job las convierte a SK
-- ---------------------------------------------------------------------
CREATE TABLE stg_asignacion (
  id_asignacion BIGINT, id_tripulante BIGINT, id_vuelo BIGINT, fecha_salida DATE, origen CHAR(3), destino CHAR(3),
  rol VARCHAR(20), horas_vuelo DECIMAL(5,2), retraso_minutos SMALLINT,
  id_pairing VARCHAR(20), orden_en_pairing TINYINT, descanso_previo_h DECIMAL(7,1), mismo_aeropuerto_previo VARCHAR(5),
  aviso_horas TINYINT, motivo_reemplazo VARCHAR(30)
) ENGINE=InnoDB;
CREATE TABLE stg_jornada (
  id_jornada BIGINT, id_tripulante BIGINT, fecha_jornada DATE, tipo_jornada VARCHAR(15), horas_servicio DECIMAL(4,2),
  tramos_volados TINYINT, horas_vuelo_dia DECIMAL(5,2), descanso_previo_h DECIMAL(7,2), horas_servicio_7d DECIMAL(6,2), margen_60h_semana DECIMAL(6,2)
) ENGINE=InnoDB;
CREATE TABLE stg_credencial (
  id_credencial VARCHAR(25), id_tripulante BIGINT, fuente VARCHAR(20), categoria VARCHAR(25), tipo VARCHAR(30), equipo VARCHAR(10),
  estado VARCHAR(20), fecha_emision DATE, fecha_vencimiento DATE
) ENGINE=InnoDB;
CREATE TABLE etl_rechazos (
  origen VARCHAR(30), clave VARCHAR(30), motivo VARCHAR(100), fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
