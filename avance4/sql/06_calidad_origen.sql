-- =====================================================================
-- Análisis de calidad de los datos de origen (PostgreSQL staging, puerto 5440)
-- Cada consulta devuelve cuántos registros tienen el problema
-- =====================================================================
SET search_path = staging;

-- 1. Nulos y campos faltantes
SELECT 'tripulante sin base o sin cargo' AS control, COUNT(*) FROM tripulante WHERE id_hub_base IS NULL OR cargo IS NULL
UNION ALL SELECT 'vuelo sin fechas reales', COUNT(*) FROM vuelo WHERE fecha_salida_real IS NULL OR fecha_llegada_real IS NULL
UNION ALL SELECT 'asignación sin horas o rol', COUNT(*) FROM asignacion_tripulacion WHERE horas_vuelo IS NULL OR rol IS NULL
UNION ALL SELECT 'certificación sin vencimiento', COUNT(*) FROM certificacion WHERE fecha_vencimiento IS NULL
UNION ALL SELECT 'tripulante sin licencia médica', COUNT(*) FROM tripulante t WHERE NOT EXISTS (SELECT 1 FROM licencia_medica l WHERE l.id_tripulante = t.id_tripulante);

-- 2. Formato
SELECT 'IATA fuera de formato [A-Z]{3}' AS control, COUNT(*) FROM aeropuerto WHERE codigo_iata !~ '^[A-Z]{3}$'
UNION ALL SELECT 'numero_vuelo fuera de formato AA9999', COUNT(*) FROM vuelo WHERE numero_vuelo !~ '^AA[0-9]{4}$'
UNION ALL SELECT 'numero_empleado fuera de formato AA999999', COUNT(*) FROM tripulante WHERE numero_empleado !~ '^AA[0-9]{6}$'
UNION ALL SELECT 'nombres con espacios sobrantes', COUNT(*) FROM tripulante WHERE nombre <> trim(nombre) OR apellido <> trim(apellido)
UNION ALL SELECT 'nombres con tilde o ñ (riesgo de codificación)', COUNT(*) FROM tripulante WHERE nombre ~ '[áéíóúñÁÉÍÓÚÑ]' OR apellido ~ '[áéíóúñÁÉÍÓÚÑ]'
UNION ALL SELECT 'códigos en MAYÚSCULAS_CON_GUION (cargo)', COUNT(*) FROM tripulante WHERE cargo ~ '^[A-Z_]+$';

-- 3. Duplicados
SELECT 'asignación duplicada (tripulante, vuelo)' AS control, COUNT(*) FROM (SELECT id_tripulante, id_vuelo FROM asignacion_tripulacion GROUP BY 1, 2 HAVING COUNT(*) > 1) x
UNION ALL SELECT 'jornada duplicada (tripulante, día)', COUNT(*) FROM (SELECT id_tripulante, fecha_jornada FROM jornada_laboral GROUP BY 1, 2 HAVING COUNT(*) > 1) x
UNION ALL SELECT 'tripulante duplicado (nombre, apellido, nacimiento)', COUNT(*) FROM (SELECT nombre, apellido, fecha_nacimiento FROM tripulante GROUP BY 1, 2, 3 HAVING COUNT(*) > 1) x
UNION ALL SELECT 'vuelo duplicado (número, día)', COUNT(*) FROM (SELECT numero_vuelo, fecha_salida_real::date FROM vuelo GROUP BY 1, 2 HAVING COUNT(*) > 1) x;

-- 4. Fuera de rango
SELECT 'llegada anterior o igual a la salida' AS control, COUNT(*) FROM vuelo WHERE fecha_llegada_real <= fecha_salida_real
UNION ALL SELECT 'retraso negativo', COUNT(*) FROM vuelo WHERE retraso_minutos < 0
UNION ALL SELECT 'horas de vuelo <= 0 o > 18', COUNT(*) FROM asignacion_tripulacion WHERE horas_vuelo <= 0 OR horas_vuelo > 18
UNION ALL SELECT 'horas asignadas distintas a la duración del vuelo (> 6 min)', COUNT(*) FROM asignacion_tripulacion a JOIN vuelo v USING (id_vuelo)
          WHERE abs(a.horas_vuelo - extract(epoch FROM v.fecha_llegada_real - v.fecha_salida_real) / 3600) > 0.1
UNION ALL SELECT 'jornada con fin <= inicio', COUNT(*) FROM jornada_laboral WHERE hora_fin <= hora_inicio
UNION ALL SELECT 'certificación que vence antes de emitirse', COUNT(*) FROM certificacion WHERE fecha_vencimiento <= fecha_emision
UNION ALL SELECT 'ingreso antes de los 18 años', COUNT(*) FROM tripulante WHERE fecha_ingreso < fecha_nacimiento + interval '18 years'
UNION ALL SELECT 'tripulante asignado a un rol distinto a su cargo', COUNT(*) FROM asignacion_tripulacion a JOIN tripulante t USING (id_tripulante) WHERE a.rol <> t.cargo;

-- 5. Reglas de negocio (se MARCAN, no se corrigen: son el insumo de la métrica de cumplimiento)
WITH j AS (SELECT *, extract(epoch FROM hora_inicio - lag(hora_fin) OVER (PARTITION BY id_tripulante ORDER BY hora_inicio)) / 3600 AS descanso FROM jornada_laboral)
SELECT 'jornadas con descanso previo < 10 h' AS control, COUNT(*) FROM j WHERE descanso < 10
UNION ALL SELECT 'estado de certificación incoherente con la fecha de corte 30/06/2026', COUNT(*) FROM certificacion
          WHERE (estado = 'VIGENTE' AND fecha_vencimiento < DATE '2026-06-30') OR (estado = 'VENCIDA' AND fecha_vencimiento >= DATE '2026-06-30')
UNION ALL SELECT 'tripulantes inactivos (sin vuelos en el período)', COUNT(*) FROM tripulante t
          WHERE estado = 'INACTIVO' AND NOT EXISTS (SELECT 1 FROM asignacion_tripulacion a WHERE a.id_tripulante = t.id_tripulante);

-- 6. Calidad en Neo4j (ejecutar en Neo4j Browser, http://localhost:7474)
-- Tramos sin descanso previo (primer tramo de cada pairing):
--   MATCH (:Pairing)-[i:INCLUYE {orden: 1}]->(:Vuelo) RETURN count(i);
-- Tramos que empiezan en un aeropuerto distinto al de llegada del anterior (reposicionamiento no registrado):
--   MATCH ()-[c:CONECTA_CON]->() RETURN c.mismo_aeropuerto AS mismo_aeropuerto, count(*) ORDER BY mismo_aeropuerto;
-- Habilitaciones sin fecha de vencimiento:
--   MATCH (h:Habilitacion) WHERE h.fecha_vencimiento IS NULL RETURN h.tipo, h.estado, count(*);
-- Asignaciones del grafo que no existen en el relacional (debe dar 0, se compara en la ETL por id_asignacion):
--   MATCH ()-[i:INCLUYE]->() RETURN count(DISTINCT i.id_asignacion);
