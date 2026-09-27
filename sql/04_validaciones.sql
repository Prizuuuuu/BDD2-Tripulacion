-- =====================================================================
-- Avance 1 - Base de Datos 2 (Septiembre 2026)
-- Grupo 5 - Subsistema Tripulación - PostgreSQL 16
-- Validación de integridad y coherencia de los datos
-- Cada regla debe devolver 0 errores.
-- =====================================================================

-- Resumen por tabla
SELECT 'region' AS tabla, count(*) AS filas FROM region
UNION ALL SELECT 'aeropuerto', count(*) FROM aeropuerto
UNION ALL SELECT 'hub', count(*) FROM hub
UNION ALL SELECT 'tripulante', count(*) FROM tripulante
UNION ALL SELECT 'certificacion', count(*) FROM certificacion
UNION ALL SELECT 'licencia_medica', count(*) FROM licencia_medica
UNION ALL SELECT 'vuelo', count(*) FROM vuelo
UNION ALL SELECT 'asignacion_tripulacion', count(*) FROM asignacion_tripulacion
UNION ALL SELECT 'jornada_laboral', count(*) FROM jornada_laboral;


-- Reglas de integridad y coherencia (resultado que muestra pgAdmin)
SELECT regla, errores
FROM (
    SELECT 1 AS n, 'Asignaciones >= 5.000' AS regla,
           CASE WHEN (SELECT count(*) FROM asignacion_tripulacion) >= 5000 THEN 0 ELSE 1 END AS errores

    UNION ALL
    SELECT 2, 'Vuelos que aterrizan antes de despegar',
           count(*) FROM vuelo WHERE fecha_llegada_real <= fecha_salida_real

    UNION ALL
    SELECT 3, 'Vuelos sin exactamente 5 tripulantes (1 PIL, 1 COP, 1 JEF, 2 AUX)',
           count(*) FROM (
               SELECT v.id_vuelo
               FROM vuelo v
               LEFT JOIN asignacion_tripulacion a ON a.id_vuelo = v.id_vuelo
               GROUP BY v.id_vuelo
               HAVING count(*) FILTER (WHERE a.rol = 'PILOTO') <> 1
                   OR count(*) FILTER (WHERE a.rol = 'COPILOTO') <> 1
                   OR count(*) FILTER (WHERE a.rol = 'JEFE_CABINA') <> 1
                   OR count(*) FILTER (WHERE a.rol = 'AUXILIAR_VUELO') <> 2
           ) AS x

    UNION ALL
    SELECT 4, 'Tripulante en dos vuelos que se cruzan',
           count(*) FROM asignacion_tripulacion a1
           JOIN vuelo v1 ON v1.id_vuelo = a1.id_vuelo
           JOIN asignacion_tripulacion a2 ON a2.id_tripulante = a1.id_tripulante
                                          AND a2.id_asignacion > a1.id_asignacion
           JOIN vuelo v2 ON v2.id_vuelo = a2.id_vuelo
           WHERE v1.fecha_salida_real < v2.fecha_llegada_real
             AND v2.fecha_salida_real < v1.fecha_llegada_real

    UNION ALL
    SELECT 5, 'Descanso menor a 10 h entre vuelos consecutivos',
           count(*) FROM (
               SELECT v.fecha_salida_real
                      - lag(v.fecha_llegada_real) OVER (PARTITION BY a.id_tripulante
                                                        ORDER BY v.fecha_salida_real) AS descanso
               FROM asignacion_tripulacion a
               JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           ) AS x
           WHERE descanso < INTERVAL '10 hours'

    UNION ALL
    SELECT 6, 'Rol distinto al cargo del tripulante',
           count(*) FROM asignacion_tripulacion a
           JOIN tripulante t ON t.id_tripulante = a.id_tripulante
           WHERE a.rol <> t.cargo

    UNION ALL
    SELECT 7, 'Tripulante inactivo con vuelos',
           count(*) FROM asignacion_tripulacion a
           JOIN tripulante t ON t.id_tripulante = a.id_tripulante
           WHERE t.estado <> 'ACTIVO'

    UNION ALL
    SELECT 8, 'Vuelo sin licencia médica vigente de la clase del rol',
           count(*) FROM asignacion_tripulacion a
           JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           WHERE NOT EXISTS (
               SELECT 1 FROM licencia_medica l
               WHERE l.id_tripulante = a.id_tripulante
                 AND l.clase_medica = CASE WHEN a.rol IN ('PILOTO', 'COPILOTO') THEN '1' ELSE '2' END
                 AND l.estado <> 'SUSPENDIDA'
                 AND l.fecha_emision <= v.fecha_salida_real::date
                 AND l.fecha_vencimiento >= v.fecha_llegada_real::date)

    UNION ALL
    SELECT 9, 'Vuelo sin certificación clave vigente (ATP / Seguridad de cabina)',
           count(*) FROM asignacion_tripulacion a
           JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           WHERE NOT EXISTS (
               SELECT 1 FROM certificacion c
               WHERE c.id_tripulante = a.id_tripulante
                 AND c.tipo_certificacion = CASE WHEN a.rol IN ('PILOTO', 'COPILOTO')
                                                 THEN 'LICENCIA_ATP' ELSE 'SEGURIDAD_CABINA' END
                 AND c.estado <> 'SUSPENDIDA'
                 AND c.fecha_emision <= v.fecha_salida_real::date
                 AND c.fecha_vencimiento >= v.fecha_llegada_real::date)

    UNION ALL
    SELECT 10, 'Licencia médica con clase distinta a la del cargo',
           count(*) FROM licencia_medica l
           JOIN tripulante t ON t.id_tripulante = l.id_tripulante
           WHERE l.clase_medica <> CASE WHEN t.cargo IN ('PILOTO', 'COPILOTO') THEN '1' ELSE '2' END

    UNION ALL
    SELECT 11, 'Estado de licencia o certificación incoherente con su vencimiento (ref. 2026-06-30)',
           (SELECT count(*) FROM licencia_medica
             WHERE (estado = 'VENCIDA' AND fecha_vencimiento >= DATE '2026-06-30')
                OR (estado = 'VIGENTE' AND fecha_vencimiento <  DATE '2026-06-30'))
         + (SELECT count(*) FROM certificacion
             WHERE (estado = 'VENCIDA' AND fecha_vencimiento >= DATE '2026-06-30')
                OR (estado = 'VIGENTE' AND fecha_vencimiento <  DATE '2026-06-30'))

    UNION ALL
    SELECT 12, 'horas_vuelo distinto a la duración real del vuelo',
           count(*) FROM asignacion_tripulacion a
           JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           WHERE a.horas_vuelo <> ROUND(EXTRACT(EPOCH FROM (v.fecha_llegada_real - v.fecha_salida_real)) / 3600, 2)

    UNION ALL
    SELECT 13, 'Asignación registrada después de la salida del vuelo',
           count(*) FROM asignacion_tripulacion a
           JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           WHERE a.fecha_asignacion > v.fecha_salida_real::date

    UNION ALL
    SELECT 14, 'Asignación sin jornada de VUELO que cubra el vuelo',
           count(*) FROM asignacion_tripulacion a
           JOIN vuelo v ON v.id_vuelo = a.id_vuelo
           WHERE NOT EXISTS (
               SELECT 1 FROM jornada_laboral j
               WHERE j.id_tripulante = a.id_tripulante
                 AND j.tipo_jornada = 'VUELO'
                 AND j.hora_inicio <= v.fecha_salida_real
                 AND j.hora_fin >= v.fecha_llegada_real)

    UNION ALL
    SELECT 15, 'Jornadas que se solapan para un mismo tripulante',
           count(*) FROM jornada_laboral j1
           JOIN jornada_laboral j2 ON j2.id_tripulante = j1.id_tripulante
                                  AND j2.id_jornada > j1.id_jornada
           WHERE j1.hora_inicio < j2.hora_fin
             AND j2.hora_inicio < j1.hora_fin

    UNION ALL
    SELECT 16, 'Vuelos con origen o destino fuera de un hub (hub-and-spoke)',
           count(*) FROM vuelo v
           WHERE v.id_aeropuerto_origen  NOT IN (SELECT id_aeropuerto FROM hub)
             AND v.id_aeropuerto_destino NOT IN (SELECT id_aeropuerto FROM hub)

    UNION ALL
    SELECT 17, 'Aeropuerto en una región distinta a la del enunciado',
           count(*) FROM aeropuerto a
           JOIN region r ON r.id_region = a.id_region
           WHERE (r.nombre_region = 'ESTE' AND a.codigo_iata NOT IN
                    ('CLT','PHL','JFK','LGA','DCA','MIA','BOS','EWR','BWI','IAD','PIT','RDU','ATL','MCO'))
              OR (r.nombre_region = 'CENTRAL' AND a.codigo_iata NOT IN
                    ('DFW','ORD','MSP','DTW','CLE','STL','MCI','MSY','IAH','AUS','SAT','MEM','BNA','MDW'))
              OR (r.nombre_region = 'OESTE' AND a.codigo_iata NOT IN
                    ('PHX','LAX','SFO','SAN','LAS','SEA','PDX','SLC','DEN','ABQ','TUS','SJC','SNA','OAK'))

    UNION ALL
    SELECT 18, 'Hub que no pertenece a la lista del enunciado',
           count(*) FROM hub h
           JOIN aeropuerto a ON a.id_aeropuerto = h.id_aeropuerto
           WHERE a.codigo_iata NOT IN ('CLT','PHL','JFK','LGA','DCA','MIA','DFW','ORD','PHX','LAX')
) AS v
ORDER BY n;
