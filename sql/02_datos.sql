-- =====================================================================
-- Avance 1 - Base de Datos 2 (Septiembre 2026)
-- Grupo 5 - Subsistema Tripulación - PostgreSQL 16
-- Carga de datos sintéticos (periodo: enero - junio 2026)
-- =====================================================================

SET client_min_messages = warning;

TRUNCATE asignacion_tripulacion, jornada_laboral, licencia_medica, certificacion,
         vuelo, tripulante, hub, aeropuerto, region RESTART IDENTITY CASCADE;

SELECT setseed(0.42);


-- ---------------------------------------------------------------------
-- Región, aeropuerto y hub
-- ---------------------------------------------------------------------
INSERT INTO region (id_region, nombre_region) VALUES
    (1, 'ESTE'), (2, 'CENTRAL'), (3, 'OESTE');

INSERT INTO aeropuerto (id_aeropuerto, id_region, codigo_iata, nombre, ciudad, estado) VALUES
    ( 1, 1, 'CLT', 'Charlotte Douglas International Airport',            'Charlotte',        'NC'),
    ( 2, 1, 'PHL', 'Philadelphia International Airport',                 'Philadelphia',     'PA'),
    ( 3, 1, 'JFK', 'John F. Kennedy International Airport',              'New York',         'NY'),
    ( 4, 1, 'LGA', 'LaGuardia Airport',                                  'New York',         'NY'),
    ( 5, 1, 'DCA', 'Ronald Reagan Washington National Airport',          'Arlington',        'VA'),
    ( 6, 1, 'MIA', 'Miami International Airport',                        'Miami',            'FL'),
    ( 7, 1, 'BOS', 'Boston Logan International Airport',                 'Boston',           'MA'),
    ( 8, 1, 'EWR', 'Newark Liberty International Airport',               'Newark',           'NJ'),
    ( 9, 1, 'BWI', 'Baltimore/Washington International Airport',         'Baltimore',        'MD'),
    (10, 1, 'IAD', 'Washington Dulles International Airport',            'Dulles',           'VA'),
    (11, 1, 'PIT', 'Pittsburgh International Airport',                   'Pittsburgh',       'PA'),
    (12, 1, 'RDU', 'Raleigh-Durham International Airport',               'Raleigh',          'NC'),
    (13, 1, 'ATL', 'Hartsfield-Jackson Atlanta International Airport',   'Atlanta',          'GA'),
    (14, 1, 'MCO', 'Orlando International Airport',                      'Orlando',          'FL'),
    (15, 2, 'DFW', 'Dallas/Fort Worth International Airport',            'Dallas',           'TX'),
    (16, 2, 'ORD', 'O''Hare International Airport',                      'Chicago',          'IL'),
    (17, 2, 'MSP', 'Minneapolis-Saint Paul International Airport',       'Minneapolis',      'MN'),
    (18, 2, 'DTW', 'Detroit Metropolitan Wayne County Airport',          'Detroit',          'MI'),
    (19, 2, 'CLE', 'Cleveland Hopkins International Airport',            'Cleveland',        'OH'),
    (20, 2, 'STL', 'St. Louis Lambert International Airport',            'St. Louis',        'MO'),
    (21, 2, 'MCI', 'Kansas City International Airport',                  'Kansas City',      'MO'),
    (22, 2, 'MSY', 'Louis Armstrong New Orleans International Airport',  'New Orleans',      'LA'),
    (23, 2, 'IAH', 'George Bush Intercontinental Airport',               'Houston',          'TX'),
    (24, 2, 'AUS', 'Austin-Bergstrom International Airport',             'Austin',           'TX'),
    (25, 2, 'SAT', 'San Antonio International Airport',                  'San Antonio',      'TX'),
    (26, 2, 'MEM', 'Memphis International Airport',                      'Memphis',          'TN'),
    (27, 2, 'BNA', 'Nashville International Airport',                    'Nashville',        'TN'),
    (28, 2, 'MDW', 'Chicago Midway International Airport',               'Chicago',          'IL'),
    (29, 3, 'PHX', 'Phoenix Sky Harbor International Airport',           'Phoenix',          'AZ'),
    (30, 3, 'LAX', 'Los Angeles International Airport',                  'Los Angeles',      'CA'),
    (31, 3, 'SFO', 'San Francisco International Airport',                'San Francisco',    'CA'),
    (32, 3, 'SAN', 'San Diego International Airport',                    'San Diego',        'CA'),
    (33, 3, 'LAS', 'Harry Reid International Airport',                   'Las Vegas',        'NV'),
    (34, 3, 'SEA', 'Seattle-Tacoma International Airport',               'Seattle',          'WA'),
    (35, 3, 'PDX', 'Portland International Airport',                     'Portland',         'OR'),
    (36, 3, 'SLC', 'Salt Lake City International Airport',               'Salt Lake City',   'UT'),
    (37, 3, 'DEN', 'Denver International Airport',                       'Denver',           'CO'),
    (38, 3, 'ABQ', 'Albuquerque International Sunport',                  'Albuquerque',      'NM'),
    (39, 3, 'TUS', 'Tucson International Airport',                       'Tucson',           'AZ'),
    (40, 3, 'SJC', 'San Jose Mineta International Airport',              'San Jose',         'CA'),
    (41, 3, 'SNA', 'John Wayne Airport',                                 'Santa Ana',        'CA'),
    (42, 3, 'OAK', 'Oakland International Airport',                      'Oakland',          'CA');

INSERT INTO hub (id_hub, id_aeropuerto, fecha_inicio_operacion) VALUES
    ( 1,  1, '1989-06-01'),   -- CLT
    ( 2,  2, '2013-12-09'),   -- PHL
    ( 3,  3, '1998-03-15'),   -- JFK
    ( 4,  4, '2002-09-01'),   -- LGA
    ( 5,  5, '2013-12-09'),   -- DCA
    ( 6,  6, '1990-01-10'),   -- MIA
    ( 7, 15, '1981-06-11'),   -- DFW
    ( 8, 16, '1982-04-01'),   -- ORD
    ( 9, 29, '2005-09-27'),   -- PHX
    (10, 30, '1985-10-01');   -- LAX


-- ---------------------------------------------------------------------
-- Tripulantes (400): 80 pilotos, 80 copilotos, 80 jefes de cabina, 160 auxiliares
-- ---------------------------------------------------------------------
INSERT INTO tripulante (fecha_nacimiento, fecha_ingreso, id_hub_base, numero_empleado,
                        nombre, apellido, cargo, estado)
SELECT t.nacimiento,
       t.nacimiento + t.edad_min_ingreso
           + ((random() * ((DATE '2025-12-31' - (t.nacimiento + t.edad_min_ingreso)::date))::int) * INTERVAL '1 day'),
       t.hub,
       'AA' || lpad((100000 + t.g * 13)::text, 6, '0'),
       (ARRAY['James','John','Robert','Michael','William','David','Richard','Joseph','Thomas','Daniel',
              'Mary','Patricia','Jennifer','Linda','Elizabeth','Susan','Jessica','Sarah','Karen','Emily',
              'José','Luis','Carlos','Jesús','Andrés','Sofía','María','Lucía','Valentina','Camila',
              'Mónica','Verónica','Inés','Ramón','Joaquín','Martín','Héctor','Ángel','Iván','Begoña'])
           [1 + floor(random() * 40)::int],
       (ARRAY['Smith','Johnson','Williams','Brown','Jones','Miller','Davis','Wilson','Anderson','Taylor',
              'Thomas','Moore','Jackson','Martin','Lee','Thompson','White','Harris','Clark','Lewis',
              'Walker','Hall','Allen','Young','King','Wright','Scott','Green','Baker','Adams',
              'Pérez','Núñez','Muñoz','Gómez','Hernández','Rodríguez','Martínez','García','López','González',
              'Sánchez','Ramírez','Díaz','Fernández','Castañeda','Ibáñez','Peña','Ordóñez','Suárez','Jiménez'])
           [1 + floor(random() * 50)::int],
       t.cargo,
       CASE WHEN random() < 0.05 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (
    SELECT s.g, s.cargo, s.edad_min_ingreso,
           (DATE '2026-06-30'
               - ((s.edad_min + floor(random() * (s.edad_max - s.edad_min + 1))::int) * INTERVAL '1 year')
               - (floor(random() * 365)::int * INTERVAL '1 day'))::date AS nacimiento,
           CASE
               WHEN h < 0.20 THEN 7    -- DFW
               WHEN h < 0.35 THEN 1    -- CLT
               WHEN h < 0.47 THEN 8    -- ORD
               WHEN h < 0.57 THEN 9    -- PHX
               WHEN h < 0.67 THEN 6    -- MIA
               WHEN h < 0.75 THEN 2    -- PHL
               WHEN h < 0.83 THEN 10   -- LAX
               WHEN h < 0.89 THEN 5    -- DCA
               WHEN h < 0.95 THEN 3    -- JFK
               ELSE 4                  -- LGA
           END AS hub
    FROM (
        SELECT g, random() AS h,
               c.cargo, c.edad_min, c.edad_max, c.edad_min_ingreso
        FROM generate_series(1, 400) AS g
        JOIN (VALUES (0, 'PILOTO',         35, 60, INTERVAL '23 years'),
                     (1, 'COPILOTO',       26, 45, INTERVAL '23 years'),
                     (2, 'JEFE_CABINA',    30, 58, INTERVAL '20 years'),
                     (3, 'AUXILIAR_VUELO', 22, 50, INTERVAL '20 years'),
                     (4, 'AUXILIAR_VUELO', 22, 50, INTERVAL '20 years'))
             AS c (resto, cargo, edad_min, edad_max, edad_min_ingreso)
          ON c.resto = g % 5
        ORDER BY g
    ) AS s
) AS t
ORDER BY t.g;


-- ---------------------------------------------------------------------
-- Certificaciones y licencias médicas
-- Certificación clave (LICENCIA_ATP / SEGURIDAD_CABINA) y licencia médica se generan
-- como una cadena de renovaciones que cubre el periodo; algunas renovaciones dejan
-- unos días sin cobertura (en esos días el tripulante no puede volar).
-- Estado según la fecha de referencia 2026-06-30.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    t            RECORD;
    ref          CONSTANT DATE := DATE '2026-06-30';
    v_tipo_clave VARCHAR(30);
    v_meses      INT;
    v_desde      DATE;
    v_hasta      DATE;
    v_estado     VARCHAR(20);
    n_cert       INT := 0;
    n_lic        INT := 0;
    v_extra      TEXT;
BEGIN
    FOR t IN SELECT * FROM tripulante ORDER BY id_tripulante LOOP

        -- certificación clave: cadena de renovaciones
        v_tipo_clave := CASE WHEN t.cargo IN ('PILOTO', 'COPILOTO') THEN 'LICENCIA_ATP' ELSE 'SEGURIDAD_CABINA' END;
        v_meses      := CASE WHEN v_tipo_clave = 'LICENCIA_ATP' THEN 24 ELSE 12 END;
        v_desde      := DATE '2024-01-01' + floor(random() * 540)::int;
        LOOP
            v_hasta := (v_desde + v_meses * INTERVAL '1 month')::date;
            v_estado := CASE
                            WHEN v_hasta < ref THEN 'VENCIDA'
                            WHEN t.estado = 'INACTIVO' THEN 'SUSPENDIDA'
                            ELSE 'VIGENTE'
                        END;
            n_cert := n_cert + 1;
            INSERT INTO certificacion (id_tripulante, fecha_emision, fecha_vencimiento,
                                       numero_certificado, tipo_certificacion, estado)
            VALUES (t.id_tripulante, v_desde, v_hasta, 'CE' || lpad(n_cert::text, 8, '0'), v_tipo_clave, v_estado);
            EXIT WHEN v_hasta >= ref;
            v_desde := v_hasta + CASE WHEN random() < 0.85 THEN 1 ELSE 4 + floor(random() * 8)::int END;
        END LOOP;

        -- certificaciones complementarias (vigentes)
        FOR v_extra IN
            SELECT unnest(CASE WHEN t.cargo IN ('PILOTO', 'COPILOTO')
                               THEN ARRAY['HABILITACION_TIPO', 'CRM']
                               WHEN random() < 0.5
                               THEN ARRAY['PRIMEROS_AUXILIOS', 'MERCANCIAS_PELIGROSAS']
                               ELSE ARRAY['PRIMEROS_AUXILIOS'] END)
        LOOP
            v_desde := DATE '2025-07-01' + floor(random() * 180)::int;
            v_meses := CASE WHEN v_extra IN ('HABILITACION_TIPO', 'CRM') THEN 12 ELSE 24 END;
            n_cert := n_cert + 1;
            INSERT INTO certificacion (id_tripulante, fecha_emision, fecha_vencimiento,
                                       numero_certificado, tipo_certificacion, estado)
            VALUES (t.id_tripulante, v_desde, (v_desde + v_meses * INTERVAL '1 month')::date,
                    'CE' || lpad(n_cert::text, 8, '0'), v_extra,
                    CASE WHEN t.estado = 'INACTIVO' THEN 'SUSPENDIDA' ELSE 'VIGENTE' END);
        END LOOP;

        -- licencia médica: clase 1 (12 meses, 6 si tiene 40 años o más) / clase 2 (24 meses)
        v_desde := DATE '2024-06-01' + floor(random() * 390)::int;
        LOOP
            IF t.cargo IN ('PILOTO', 'COPILOTO') THEN
                v_meses := CASE WHEN age(v_desde, t.fecha_nacimiento) >= INTERVAL '40 years' THEN 6 ELSE 12 END;
            ELSE
                v_meses := 24;
            END IF;
            v_hasta := (v_desde + v_meses * INTERVAL '1 month')::date;
            v_estado := CASE
                            WHEN v_hasta < ref THEN 'VENCIDA'
                            WHEN t.estado = 'INACTIVO' THEN 'SUSPENDIDA'
                            ELSE 'VIGENTE'
                        END;
            n_lic := n_lic + 1;
            INSERT INTO licencia_medica (id_tripulante, fecha_emision, fecha_vencimiento, numero_licencia,
                                         clase_medica, restricciones, estado)
            VALUES (t.id_tripulante, v_desde, v_hasta, 'LM' || lpad(n_lic::text, 8, '0'),
                    CASE WHEN t.cargo IN ('PILOTO', 'COPILOTO') THEN '1' ELSE '2' END,
                    CASE WHEN random() < 0.85 THEN 'NINGUNA'
                         WHEN random() < 0.80 THEN 'USO DE LENTES CORRECTIVOS'
                         ELSE 'USO DE AUDIFONOS' END,
                    v_estado);
            EXIT WHEN v_hasta >= ref;
            v_desde := v_hasta + CASE WHEN random() < 0.80 THEN 1 ELSE 3 + floor(random() * 10)::int END;
        END LOOP;
    END LOOP;
END;
$$;


-- ---------------------------------------------------------------------
-- Vuelos (1.100): 100 rutas hub <-> destino, número impar ida / par vuelta
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_ruta;
CREATE TEMP TABLE tmp_ruta AS
SELECT r.id_ruta, r.hub_aeropuerto, r.destino,
       -- duración base según la distancia entre regiones (en minutos)
       CASE abs(ah.id_region - ad.id_region)
           WHEN 0 THEN  90 + floor(random() * 60)::int
           WHEN 1 THEN 150 + floor(random() * 60)::int
           ELSE        270 + floor(random() * 90)::int
       END AS minutos
FROM (
    SELECT g AS id_ruta,
           h.id_aeropuerto AS hub_aeropuerto,
           d.id_aeropuerto AS destino
    FROM generate_series(1, 100) AS g
    CROSS JOIN LATERAL (
        SELECT id_aeropuerto FROM hub ORDER BY random() + g * 0 LIMIT 1
    ) AS h
    CROSS JOIN LATERAL (
        SELECT id_aeropuerto FROM aeropuerto
        WHERE id_aeropuerto <> h.id_aeropuerto
        ORDER BY random() + g * 0 LIMIT 1
    ) AS d
) AS r
JOIN aeropuerto ah ON ah.id_aeropuerto = r.hub_aeropuerto
JOIN aeropuerto ad ON ad.id_aeropuerto = r.destino;

INSERT INTO vuelo (fecha_salida_real, fecha_llegada_real, id_aeropuerto_origen, id_aeropuerto_destino,
                   retraso_minutos, numero_vuelo, estado)
SELECT v.salida,
       v.salida + (v.minutos + v.extra_desvio) * INTERVAL '1 minute',
       v.origen, v.destino, v.retraso, v.numero, v.estado
FROM (
    SELECT p.programada + p.retraso * INTERVAL '1 minute' AS salida,
           p.minutos + floor(random() * 21)::int - 10 AS minutos,
           CASE WHEN p.desviado THEN 30 + floor(random() * 61)::int ELSE 0 END AS extra_desvio,
           p.origen, p.destino, p.retraso,
           'AA' || lpad((1000 + p.id_ruta * 2 - CASE WHEN p.ida THEN 1 ELSE 0 END)::text, 4, '0') AS numero,
           CASE WHEN p.desviado THEN 'DESVIADO' ELSE 'COMPLETADO' END AS estado,
           p.g
    FROM (
        SELECT q.g, q.id_ruta, q.minutos, q.ida,
               CASE WHEN q.ida THEN q.hub_aeropuerto ELSE q.destino END AS origen,
               CASE WHEN q.ida THEN q.destino ELSE q.hub_aeropuerto END AS destino,
               (DATE '2026-01-01' + (q.g - 1) * 181 / 1100)
                   + TIME '06:00' + (floor(random() * 169)::int * 5) * INTERVAL '1 minute' AS programada,
               CASE WHEN random() < 0.70 THEN 0 ELSE 5 + floor(random() ^ 2 * 175)::int END AS retraso,
               random() < 0.02 AS desviado
        FROM (
            SELECT s.g, r.*, s.ida
            FROM (
                SELECT g,
                       1 + (g * 37 + floor(random() * 3)::int) % 100 AS id_ruta,
                       random() < 0.5 AS ida
                FROM generate_series(1, 1100) AS g
                ORDER BY g
            ) AS s
            JOIN tmp_ruta r ON r.id_ruta = s.id_ruta
            ORDER BY s.g
        ) AS q
    ) AS p
) AS v
ORDER BY v.salida, v.g;


-- ---------------------------------------------------------------------
-- Asignaciones (5 por vuelo = 5.500)
-- Se recorren los vuelos en orden cronológico y para cada puesto se elige
-- un tripulante activo del mismo cargo que:
--   * tenga licencia médica de su clase y certificación clave vigentes,
--   * haya descansado al menos 10 h desde su último vuelo,
--   * no tenga otro vuelo ese mismo día,
-- priorizando a quien tenga menos vuelos asignados.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_carga;
CREATE TEMP TABLE tmp_carga AS
SELECT id_tripulante, cargo, 0 AS n_vuelos,
       NULL::timestamp AS ultima_llegada, NULL::date AS ultimo_dia
FROM tripulante
WHERE estado = 'ACTIVO';

DO $$
DECLARE
    v        RECORD;
    p        RECORD;
    v_elegido BIGINT;
    v_usados BIGINT[];
BEGIN
    FOR v IN SELECT * FROM vuelo ORDER BY fecha_salida_real, id_vuelo LOOP
        v_usados := ARRAY[]::BIGINT[];
        FOR p IN SELECT * FROM (VALUES (1, 'PILOTO'), (2, 'COPILOTO'), (3, 'JEFE_CABINA'),
                                       (4, 'AUXILIAR_VUELO'), (5, 'AUXILIAR_VUELO')) AS x (orden, rol)
                 ORDER BY orden LOOP
            SELECT c.id_tripulante INTO v_elegido
            FROM tmp_carga c
            WHERE c.cargo = p.rol
              AND c.id_tripulante <> ALL (v_usados)
              AND (c.ultima_llegada IS NULL OR c.ultima_llegada <= v.fecha_salida_real - INTERVAL '10 hours')
              AND (c.ultimo_dia IS NULL OR c.ultimo_dia <> v.fecha_salida_real::date)
              AND EXISTS (SELECT 1 FROM licencia_medica l
                          WHERE l.id_tripulante = c.id_tripulante
                            AND l.estado <> 'SUSPENDIDA'
                            AND l.fecha_emision <= v.fecha_salida_real::date
                            AND l.fecha_vencimiento >= v.fecha_llegada_real::date)
              AND EXISTS (SELECT 1 FROM certificacion ce
                          WHERE ce.id_tripulante = c.id_tripulante
                            AND ce.tipo_certificacion IN ('LICENCIA_ATP', 'SEGURIDAD_CABINA')
                            AND ce.estado <> 'SUSPENDIDA'
                            AND ce.fecha_emision <= v.fecha_salida_real::date
                            AND ce.fecha_vencimiento >= v.fecha_llegada_real::date)
            ORDER BY c.n_vuelos, random()
            LIMIT 1;

            IF v_elegido IS NULL THEN
                RAISE EXCEPTION 'No hay % disponible para el vuelo %', p.rol, v.id_vuelo;
            END IF;

            INSERT INTO asignacion_tripulacion (id_tripulante, id_vuelo, fecha_asignacion, horas_vuelo, rol)
            VALUES (v_elegido, v.id_vuelo,
                    v.fecha_salida_real::date - (1 + floor(random() * 14)::int),
                    ROUND(EXTRACT(EPOCH FROM (v.fecha_llegada_real - v.fecha_salida_real)) / 3600, 2),
                    p.rol);

            UPDATE tmp_carga
               SET n_vuelos = n_vuelos + 1,
                   ultima_llegada = v.fecha_llegada_real,
                   ultimo_dia = v.fecha_salida_real::date
             WHERE id_tripulante = v_elegido;

            v_usados := v_usados || v_elegido;
            v_elegido := NULL;
        END LOOP;
    END LOOP;
END;
$$;


-- ---------------------------------------------------------------------
-- Jornadas laborales
-- VUELO: desde 1 h antes de la salida hasta 30 min después de la llegada.
-- RESERVA / ENTRENAMIENTO: días sin vuelo de cada tripulante activo.
-- ---------------------------------------------------------------------
INSERT INTO jornada_laboral (id_tripulante, hora_inicio, hora_fin, fecha_jornada, tipo_jornada)
SELECT a.id_tripulante,
       v.fecha_salida_real - INTERVAL '1 hour',
       v.fecha_llegada_real + INTERVAL '30 minutes',
       (v.fecha_salida_real - INTERVAL '1 hour')::date,
       'VUELO'
FROM asignacion_tripulacion a
JOIN vuelo v ON v.id_vuelo = a.id_vuelo
ORDER BY v.fecha_salida_real, a.id_asignacion;

INSERT INTO jornada_laboral (id_tripulante, hora_inicio, hora_fin, fecha_jornada, tipo_jornada)
SELECT x.id_tripulante,
       x.dia + x.inicio,
       x.dia + x.inicio + x.duracion,
       x.dia,
       x.tipo
FROM (
    SELECT DISTINCT ON (c.id_tripulante, c.dia)
           c.id_tripulante, c.dia, c.tipo,
           CASE WHEN c.tipo = 'ENTRENAMIENTO' THEN INTERVAL '8 hours'
                ELSE (6 + floor(random() * 7)::int) * INTERVAL '1 hour' END AS inicio,
           CASE WHEN c.tipo = 'ENTRENAMIENTO' THEN INTERVAL '8 hours'
                ELSE (8 + floor(random() * 5)::int) * INTERVAL '1 hour' END AS duracion
    FROM (
        SELECT t.id_tripulante,
               DATE '2026-01-01' + floor(random() * 181)::int AS dia,
               CASE WHEN random() < 0.6 THEN 'RESERVA' ELSE 'ENTRENAMIENTO' END AS tipo
        FROM tripulante t
        CROSS JOIN generate_series(1, 3)
        WHERE t.estado = 'ACTIVO'
    ) AS c
    WHERE NOT EXISTS (SELECT 1 FROM jornada_laboral j
                      WHERE j.id_tripulante = c.id_tripulante AND j.fecha_jornada = c.dia)
    ORDER BY c.id_tripulante, c.dia
) AS x
ORDER BY x.dia, x.id_tripulante;


-- ---------------------------------------------------------------------
-- Estadísticas y conteo final
-- ---------------------------------------------------------------------
ANALYZE;

SELECT 'region' AS tabla, count(*) AS filas FROM region
UNION ALL SELECT 'aeropuerto', count(*) FROM aeropuerto
UNION ALL SELECT 'hub', count(*) FROM hub
UNION ALL SELECT 'tripulante', count(*) FROM tripulante
UNION ALL SELECT 'certificacion', count(*) FROM certificacion
UNION ALL SELECT 'licencia_medica', count(*) FROM licencia_medica
UNION ALL SELECT 'vuelo', count(*) FROM vuelo
UNION ALL SELECT 'asignacion_tripulacion', count(*) FROM asignacion_tripulacion
UNION ALL SELECT 'jornada_laboral', count(*) FROM jornada_laboral;
