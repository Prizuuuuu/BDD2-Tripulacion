-- =====================================================================
-- 07. Consultas distribuidas y costo de comunicación
-- =====================================================================
-- Consulta 1: horas de vuelo acumuladas por base operativa (sugerida para Tripulación)
-- Consulta 2: horas que cada región base vuela en vuelos de cada región de operación
-- Cada consulta se ejecuta con varias estrategias de Citus y sobre el staging (Unidad 1).

\timing on


-- =====================================================================
-- CONSULTA 1. Horas de vuelo acumuladas por base operativa
-- =====================================================================

-- 1A. Co-located join + tablas de referencia
--     asignacion_horas y tripulante están colocadas por id_region; hub, aeropuerto
--     y region están en todos los nodos. Cada worker resuelve su región completa.
SET citus.explain_all_tasks = on;   -- muestra la tarea de cada worker
EXPLAIN (ANALYZE)
SELECT r.nombre_region, a.codigo_iata AS base,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN tripulante t  ON t.id_tripulante = h.id_tripulante AND t.id_region = h.id_region
JOIN hub hb        ON hb.id_hub = t.id_hub_base
JOIN aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN region r      ON r.id_region = t.id_region
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;
RESET citus.explain_all_tasks;

-- 1B. Repartition join: el join no usa la columna de distribución,
--     Citus redistribuye las filas por id_tripulante entre los workers.
SET citus.enable_repartition_joins = on;
SET citus.multi_shard_modify_mode TO 'sequential';   -- el repartition crea tablas intermedias; con tablas de referencia en el join deben crearse en serie
EXPLAIN (ANALYZE)
SELECT r.nombre_region, a.codigo_iata AS base,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN tripulante t  ON t.id_tripulante = h.id_tripulante
JOIN hub hb        ON hb.id_hub = t.id_hub_base
JOIN aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN region r      ON r.id_region = t.id_region
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;
RESET citus.enable_repartition_joins;
RESET citus.multi_shard_modify_mode;

-- 1C. Router: una sola región (ESTE). El coordinador envía toda la consulta al worker 1.
EXPLAIN (ANALYZE)
SELECT a.codigo_iata AS base,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN tripulante t  ON t.id_tripulante = h.id_tripulante AND t.id_region = h.id_region
JOIN hub hb        ON hb.id_hub = t.id_hub_base
JOIN aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
WHERE h.id_region = 1
GROUP BY a.codigo_iata
ORDER BY base;

-- 1D. Staging central (Unidad 1): misma consulta en un solo nodo
EXPLAIN (ANALYZE)
SELECT r.nombre_region, a.codigo_iata AS base,
       count(*) AS asignaciones, sum(x.horas_vuelo) AS horas_vuelo
FROM staging.asignacion_tripulacion x
JOIN staging.tripulante t  ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb        ON hb.id_hub = t.id_hub_base
JOIN staging.aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN staging.region r      ON r.id_region = a.id_region
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;

-- Resultado (debe ser igual en las cuatro variantes para las regiones que cubren)
SELECT r.nombre_region, a.codigo_iata AS base,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN tripulante t  ON t.id_tripulante = h.id_tripulante AND t.id_region = h.id_region
JOIN hub hb        ON hb.id_hub = t.id_hub_base
JOIN aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN region r      ON r.id_region = t.id_region
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;


-- =====================================================================
-- CONSULTA 2. Horas por región base del tripulante y región de operación del vuelo
-- =====================================================================
-- Une los dos fragmentos verticales de la asignación, que están en nodos distintos
-- cuando el tripulante vuela fuera de su región: no hay co-localización posible.

-- 2A. Repartition join
SET citus.enable_repartition_joins = on;
SET citus.multi_shard_modify_mode TO 'sequential';   -- el repartition crea tablas intermedias; con tablas de referencia en el join deben crearse en serie
EXPLAIN (ANALYZE)
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN asignacion_operacion o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region
JOIN region ro ON ro.id_region = o.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;
RESET citus.enable_repartition_joins;
RESET citus.multi_shard_modify_mode;

-- 2B. Gather en el coordinador: se traen al coordinador las columnas necesarias de
--     ambos fragmentos y el join se hace allí.
EXPLAIN (ANALYZE)
WITH h AS MATERIALIZED (SELECT id_asignacion, id_region, horas_vuelo FROM asignacion_horas),
     o AS MATERIALIZED (SELECT id_asignacion, id_region FROM asignacion_operacion)
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM h
JOIN o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region
JOIN region ro ON ro.id_region = o.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;

-- 2C. Staging central (Unidad 1)
EXPLAIN (ANALYZE)
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(x.horas_vuelo) AS horas_vuelo
FROM staging.asignacion_tripulacion x
JOIN staging.tripulante t   ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb         ON hb.id_hub = t.id_hub_base
JOIN staging.aeropuerto ab  ON ab.id_aeropuerto = hb.id_aeropuerto
JOIN staging.vuelo v        ON v.id_vuelo = x.id_vuelo
JOIN staging.aeropuerto av  ON av.id_aeropuerto = v.id_aeropuerto_origen
JOIN staging.region rb      ON rb.id_region = ab.id_region
JOIN staging.region ro      ON ro.id_region = av.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;

-- Resultado
SET citus.enable_repartition_joins = on;
SET citus.multi_shard_modify_mode TO 'sequential';   -- el repartition crea tablas intermedias; con tablas de referencia en el join deben crearse en serie
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN asignacion_operacion o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region
JOIN region ro ON ro.id_region = o.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;
RESET citus.enable_repartition_joins;
RESET citus.multi_shard_modify_mode;
