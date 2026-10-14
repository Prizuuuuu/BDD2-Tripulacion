-- =====================================================================
-- 04. Carga de datos: staging central (Unidad 1) -> fragmentos
-- =====================================================================
-- id_region se calcula con las reglas de partición del diseño:
--   tripulante y derivados : región del aeropuerto del hub base
--   vuelo y su manifiesto  : región del aeropuerto de origen

-- Tablas de referencia (se copian a los 4 nodos)
INSERT INTO region (id_region, nombre_region)
SELECT id_region, nombre_region FROM staging.region;
INSERT INTO aeropuerto (id_aeropuerto, id_region, codigo_iata, nombre, ciudad, estado)
SELECT id_aeropuerto, id_region, codigo_iata, nombre, ciudad, estado FROM staging.aeropuerto;
INSERT INTO hub (id_hub, id_aeropuerto, fecha_inicio_operacion)
SELECT id_hub, id_aeropuerto, fecha_inicio_operacion FROM staging.hub;

BEGIN;

-- Tabla auxiliar con la región de cada tripulante y de cada vuelo
CREATE TEMP TABLE tmp_region_tripulante AS
SELECT t.id_tripulante, a.id_region
FROM staging.tripulante t
JOIN staging.hub h        ON h.id_hub = t.id_hub_base
JOIN staging.aeropuerto a ON a.id_aeropuerto = h.id_aeropuerto;

CREATE TEMP TABLE tmp_region_vuelo AS
SELECT v.id_vuelo, a.id_region
FROM staging.vuelo v
JOIN staging.aeropuerto a ON a.id_aeropuerto = v.id_aeropuerto_origen;

INSERT INTO tripulante (id_tripulante, id_region, id_hub_base, numero_empleado, cargo, estado)
SELECT t.id_tripulante, r.id_region, t.id_hub_base, t.numero_empleado, t.cargo, t.estado
FROM staging.tripulante t
JOIN tmp_region_tripulante r USING (id_tripulante);

INSERT INTO tripulante_personal (id_tripulante, fecha_nacimiento, fecha_ingreso, nombre, apellido)
SELECT id_tripulante, fecha_nacimiento, fecha_ingreso, nombre, apellido
FROM staging.tripulante;

INSERT INTO certificacion (id_certificacion, id_region, id_tripulante, fecha_emision, fecha_vencimiento,
                           numero_certificado, tipo_certificacion, estado)
SELECT c.id_certificacion, r.id_region, c.id_tripulante, c.fecha_emision, c.fecha_vencimiento,
       c.numero_certificado, c.tipo_certificacion, c.estado
FROM staging.certificacion c
JOIN tmp_region_tripulante r USING (id_tripulante);

INSERT INTO licencia_medica (id_licencia, id_region, id_tripulante, fecha_emision, fecha_vencimiento,
                             numero_licencia, clase_medica, restricciones, estado)
SELECT l.id_licencia, r.id_region, l.id_tripulante, l.fecha_emision, l.fecha_vencimiento,
       l.numero_licencia, l.clase_medica, l.restricciones, l.estado
FROM staging.licencia_medica l
JOIN tmp_region_tripulante r USING (id_tripulante);

INSERT INTO jornada_laboral (id_jornada, id_region, id_tripulante, hora_inicio, hora_fin, fecha_jornada, tipo_jornada)
SELECT j.id_jornada, r.id_region, j.id_tripulante, j.hora_inicio, j.hora_fin, j.fecha_jornada, j.tipo_jornada
FROM staging.jornada_laboral j
JOIN tmp_region_tripulante r USING (id_tripulante);

INSERT INTO vuelo (id_vuelo, id_region, fecha_salida_real, fecha_llegada_real, id_aeropuerto_origen,
                   id_aeropuerto_destino, retraso_minutos, numero_vuelo, estado)
SELECT v.id_vuelo, r.id_region, v.fecha_salida_real, v.fecha_llegada_real, v.id_aeropuerto_origen,
       v.id_aeropuerto_destino, v.retraso_minutos, v.numero_vuelo, v.estado
FROM staging.vuelo v
JOIN tmp_region_vuelo r USING (id_vuelo);

INSERT INTO asignacion_operacion (id_asignacion, id_region, id_vuelo, fecha_asignacion, rol)
SELECT a.id_asignacion, r.id_region, a.id_vuelo, a.fecha_asignacion, a.rol
FROM staging.asignacion_tripulacion a
JOIN tmp_region_vuelo r USING (id_vuelo);

INSERT INTO asignacion_horas (id_asignacion, id_region, id_tripulante, horas_vuelo)
SELECT a.id_asignacion, r.id_region, a.id_tripulante, a.horas_vuelo
FROM staging.asignacion_tripulacion a
JOIN tmp_region_tripulante r USING (id_tripulante);

COMMIT;

-- Las secuencias de identidad continúan después del último id cargado
SELECT setval(pg_get_serial_sequence('tripulante', 'id_tripulante'),             (SELECT max(id_tripulante)    FROM tripulante));
SELECT setval(pg_get_serial_sequence('certificacion', 'id_certificacion'),       (SELECT max(id_certificacion) FROM certificacion));
SELECT setval(pg_get_serial_sequence('licencia_medica', 'id_licencia'),          (SELECT max(id_licencia)      FROM licencia_medica));
SELECT setval(pg_get_serial_sequence('jornada_laboral', 'id_jornada'),           (SELECT max(id_jornada)       FROM jornada_laboral));
SELECT setval(pg_get_serial_sequence('vuelo', 'id_vuelo'),                       (SELECT max(id_vuelo)         FROM vuelo));
SELECT setval(pg_get_serial_sequence('asignacion_operacion', 'id_asignacion'),   (SELECT max(id_asignacion)    FROM asignacion_operacion));

ANALYZE;

-- Conteo: staging vs distribuido (deben coincidir)
SELECT 'region' AS tabla, (SELECT count(*) FROM staging.region) AS staging, (SELECT count(*) FROM region) AS distribuido
UNION ALL SELECT 'aeropuerto', (SELECT count(*) FROM staging.aeropuerto), (SELECT count(*) FROM aeropuerto)
UNION ALL SELECT 'hub', (SELECT count(*) FROM staging.hub), (SELECT count(*) FROM hub)
UNION ALL SELECT 'tripulante', (SELECT count(*) FROM staging.tripulante), (SELECT count(*) FROM tripulante)
UNION ALL SELECT 'tripulante_personal', (SELECT count(*) FROM staging.tripulante), (SELECT count(*) FROM tripulante_personal)
UNION ALL SELECT 'certificacion', (SELECT count(*) FROM staging.certificacion), (SELECT count(*) FROM certificacion)
UNION ALL SELECT 'licencia_medica', (SELECT count(*) FROM staging.licencia_medica), (SELECT count(*) FROM licencia_medica)
UNION ALL SELECT 'jornada_laboral', (SELECT count(*) FROM staging.jornada_laboral), (SELECT count(*) FROM jornada_laboral)
UNION ALL SELECT 'vuelo', (SELECT count(*) FROM staging.vuelo), (SELECT count(*) FROM vuelo)
UNION ALL SELECT 'asignacion_operacion', (SELECT count(*) FROM staging.asignacion_tripulacion), (SELECT count(*) FROM asignacion_operacion)
UNION ALL SELECT 'asignacion_horas', (SELECT count(*) FROM staging.asignacion_tripulacion), (SELECT count(*) FROM asignacion_horas);
