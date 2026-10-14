-- =====================================================================
-- 05c. Reconstrucción de las relaciones a partir de sus fragmentos
-- =====================================================================
-- Cada vista implementa el árbol de reconstrucción del diseño. Se compara con
-- el staging (Unidad 1) en ambos sentidos: 0 filas = la relación se reconstruye igual.

SET citus.enable_repartition_joins = on;
SET citus.multi_shard_modify_mode TO 'sequential';

-- tripulante = (TO1 ∪ TO2 ∪ TO3) ⋈ id_tripulante TP
CREATE OR REPLACE VIEW tripulante_reconstruido AS
SELECT o.id_tripulante, p.fecha_nacimiento, p.fecha_ingreso, o.id_hub_base, o.numero_empleado,
       p.nombre, p.apellido, o.cargo, o.estado
FROM tripulante o
JOIN tripulante_personal p ON p.id_tripulante = o.id_tripulante;

-- asignacion_tripulacion = (AO1 ∪ AO2 ∪ AO3) ⋈ id_asignacion (AH1 ∪ AH2 ∪ AH3)
CREATE OR REPLACE VIEW asignacion_reconstruida AS
SELECT o.id_asignacion, h.id_tripulante, o.id_vuelo, o.fecha_asignacion, h.horas_vuelo, o.rol
FROM asignacion_operacion o
JOIN asignacion_horas h ON h.id_asignacion = o.id_asignacion;

-- Completitud y reconstrucción: diferencias con el staging en ambos sentidos
SELECT 'tripulante: staging - reconstruida' AS prueba, count(*) AS filas_distintas
FROM (SELECT * FROM staging.tripulante EXCEPT SELECT * FROM tripulante_reconstruido) d
UNION ALL
SELECT 'tripulante: reconstruida - staging', count(*)
FROM (SELECT * FROM tripulante_reconstruido EXCEPT SELECT * FROM staging.tripulante) d
UNION ALL
SELECT 'asignacion: staging - reconstruida', count(*)
FROM (SELECT * FROM staging.asignacion_tripulacion
      EXCEPT SELECT * FROM asignacion_reconstruida) d
UNION ALL
SELECT 'asignacion: reconstruida - staging', count(*)
FROM (SELECT * FROM asignacion_reconstruida WHERE id_asignacion <= 5500
      EXCEPT SELECT * FROM staging.asignacion_tripulacion) d;

-- Fragmentaciones horizontales: la unión de los 3 fragmentos tiene las mismas filas que el staging
SELECT 'vuelo' AS relacion,
       (SELECT count(*) FROM (SELECT id_vuelo, fecha_salida_real, fecha_llegada_real, id_aeropuerto_origen,
                                     id_aeropuerto_destino, retraso_minutos, numero_vuelo, estado
                              FROM staging.vuelo
                              EXCEPT
                              SELECT id_vuelo, fecha_salida_real, fecha_llegada_real, id_aeropuerto_origen,
                                     id_aeropuerto_destino, retraso_minutos, numero_vuelo, estado
                              FROM vuelo) d) AS faltan
UNION ALL
SELECT 'certificacion',
       (SELECT count(*) FROM (SELECT id_certificacion, id_tripulante, fecha_emision, fecha_vencimiento,
                                     numero_certificado, tipo_certificacion, estado FROM staging.certificacion
                              EXCEPT
                              SELECT id_certificacion, id_tripulante, fecha_emision, fecha_vencimiento,
                                     numero_certificado, tipo_certificacion, estado FROM certificacion) d)
UNION ALL
SELECT 'licencia_medica',
       (SELECT count(*) FROM (SELECT id_licencia, id_tripulante, fecha_emision, fecha_vencimiento, numero_licencia,
                                     clase_medica, restricciones, estado FROM staging.licencia_medica
                              EXCEPT
                              SELECT id_licencia, id_tripulante, fecha_emision, fecha_vencimiento, numero_licencia,
                                     clase_medica, restricciones, estado FROM licencia_medica) d)
UNION ALL
SELECT 'jornada_laboral',
       (SELECT count(*) FROM (SELECT id_jornada, id_tripulante, hora_inicio, hora_fin, fecha_jornada, horas_servicio,
                                     tipo_jornada FROM staging.jornada_laboral
                              EXCEPT
                              SELECT id_jornada, id_tripulante, hora_inicio, hora_fin, fecha_jornada, horas_servicio,
                                     tipo_jornada FROM jornada_laboral) d);

-- Disyunción: ninguna fila está en dos fragmentos (cada id aparece en una sola región)
SELECT 'tripulante' AS relacion, count(*) AS ids_repetidos
FROM (SELECT id_tripulante FROM tripulante GROUP BY id_tripulante HAVING count(DISTINCT id_region) > 1) d
UNION ALL
SELECT 'vuelo', count(*) FROM (SELECT id_vuelo FROM vuelo GROUP BY id_vuelo HAVING count(DISTINCT id_region) > 1) d
UNION ALL
SELECT 'asignacion_operacion', count(*)
FROM (SELECT id_asignacion FROM asignacion_operacion GROUP BY id_asignacion HAVING count(DISTINCT id_region) > 1) d
UNION ALL
SELECT 'asignacion_horas', count(*)
FROM (SELECT id_asignacion FROM asignacion_horas GROUP BY id_asignacion HAVING count(DISTINCT id_region) > 1) d;

RESET citus.enable_repartition_joins;
RESET citus.multi_shard_modify_mode;
