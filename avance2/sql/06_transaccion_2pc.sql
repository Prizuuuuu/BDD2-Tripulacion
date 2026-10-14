-- =====================================================================
-- 06. Transacción distribuida (2PC)
-- Escenario: asignar un tripulante con base en una región a un vuelo que opera desde otra.
--   asignacion_operacion -> worker de la región del vuelo
--   asignacion_horas     -> worker de la región base del tripulante
-- La misma transacción escribe en dos workers, por lo que Citus la confirma con 2PC.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6.1 Procedimiento de asignación (reemplaza al trigger de la Unidad 1)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION asignar_tripulante(p_id_tripulante    BIGINT,
                                              p_id_vuelo         BIGINT,
                                              p_fecha_asignacion DATE)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    v_region_trip   SMALLINT;
    v_cargo         VARCHAR(20);
    v_estado        VARCHAR(20);
    v_region_vuelo  SMALLINT;
    v_salida        TIMESTAMP;
    v_llegada       TIMESTAMP;
    v_clase         CHAR(1);
    v_asignaciones  BIGINT[];
    v_id            BIGINT;
BEGIN
    SELECT id_region, cargo, estado
      INTO v_region_trip, v_cargo, v_estado
      FROM tripulante
     WHERE id_tripulante = p_id_tripulante;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el tripulante %', p_id_tripulante;
    END IF;
    IF v_estado <> 'ACTIVO' THEN
        RAISE EXCEPTION 'El tripulante % está inactivo', p_id_tripulante;
    END IF;

    SELECT id_region, fecha_salida_real, fecha_llegada_real
      INTO v_region_vuelo, v_salida, v_llegada
      FROM vuelo
     WHERE id_vuelo = p_id_vuelo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el vuelo %', p_id_vuelo;
    END IF;

    IF p_fecha_asignacion > v_salida::date THEN
        RAISE EXCEPTION 'La asignación (%) no puede ser posterior a la salida del vuelo (%)',
                        p_fecha_asignacion, v_salida::date;
    END IF;

    -- Certificado médico vigente de la clase que exige el cargo (consulta en la región del tripulante)
    v_clase := CASE WHEN v_cargo IN ('PILOTO', 'COPILOTO') THEN '1' ELSE '2' END;
    IF NOT EXISTS (
        SELECT 1
          FROM licencia_medica l
         WHERE l.id_region = v_region_trip
           AND l.id_tripulante = p_id_tripulante
           AND l.clase_medica = v_clase
           AND l.estado <> 'SUSPENDIDA'
           AND l.fecha_emision <= v_salida::date
           AND l.fecha_vencimiento >= v_llegada::date
    ) THEN
        RAISE EXCEPTION 'El tripulante % no tiene certificado médico clase % vigente', p_id_tripulante, v_clase;
    END IF;

    -- Cruce de horarios: primero sus asignaciones (región base) y luego sus vuelos (cualquier región)
    SELECT array_agg(id_asignacion)
      INTO v_asignaciones
      FROM asignacion_horas
     WHERE id_region = v_region_trip
       AND id_tripulante = p_id_tripulante;

    IF EXISTS (
        SELECT 1
          FROM asignacion_operacion o
          JOIN vuelo v ON v.id_vuelo = o.id_vuelo AND v.id_region = o.id_region
         WHERE o.id_asignacion = ANY (coalesce(v_asignaciones, '{}'))
           AND v.fecha_salida_real  < v_llegada
           AND v.fecha_llegada_real > v_salida
    ) THEN
        RAISE EXCEPTION 'El tripulante % ya tiene un vuelo que se cruza con el vuelo %', p_id_tripulante, p_id_vuelo;
    END IF;

    -- Escritura en el nodo de la región del vuelo
    INSERT INTO asignacion_operacion (id_region, id_vuelo, fecha_asignacion, rol)
    VALUES (v_region_vuelo, p_id_vuelo, p_fecha_asignacion, v_cargo)
    RETURNING id_asignacion INTO v_id;

    -- Escritura en el nodo de la región base del tripulante
    INSERT INTO asignacion_horas (id_asignacion, id_region, id_tripulante, horas_vuelo)
    VALUES (v_id, v_region_trip, p_id_tripulante,
            ROUND(EXTRACT(EPOCH FROM (v_llegada - v_salida)) / 3600, 2));

    RETURN v_id;
END;
$$;


-- ---------------------------------------------------------------------
-- 6.2 Datos del escenario
-- ---------------------------------------------------------------------
-- Vuelo nuevo que opera desde la región CENTRAL (DFW -> ORD)
INSERT INTO vuelo (id_region, fecha_salida_real, fecha_llegada_real, id_aeropuerto_origen,
                   id_aeropuerto_destino, retraso_minutos, numero_vuelo, estado)
SELECT 2, '2026-06-30 14:00', '2026-06-30 16:25', o.id_aeropuerto, d.id_aeropuerto, 0, 'AA2PC1', 'COMPLETADO'
FROM aeropuerto o, aeropuerto d
WHERE o.codigo_iata = 'DFW' AND d.codigo_iata = 'ORD'
RETURNING id_vuelo, id_region, numero_vuelo
\gset v_

-- Piloto con base en la región ESTE, activo, con certificado clase 1 vigente y sin vuelos ese día
SELECT t.id_tripulante, t.id_region, t.cargo, a.codigo_iata AS base
FROM tripulante t
JOIN hub h        ON h.id_hub = t.id_hub_base
JOIN aeropuerto a ON a.id_aeropuerto = h.id_aeropuerto
WHERE t.id_region = 1
  AND t.cargo = 'PILOTO'
  AND t.estado = 'ACTIVO'
  AND EXISTS (SELECT 1 FROM licencia_medica l
               WHERE l.id_region = 1 AND l.id_tripulante = t.id_tripulante AND l.clase_medica = '1'
                 AND l.estado <> 'SUSPENDIDA'
                 AND l.fecha_emision <= DATE '2026-06-30' AND l.fecha_vencimiento >= DATE '2026-06-30')
ORDER BY t.id_tripulante
LIMIT 1
\gset t_

\echo Tripulante :t_id_tripulante (base :t_base, región :t_id_region) -> vuelo :v_numero_vuelo (región :v_id_region)


-- ---------------------------------------------------------------------
-- 6.3 Transacción 2PC con COMMIT: se registran los mensajes que envía el coordinador
-- ---------------------------------------------------------------------
-- Limpia del log los registros de transacciones anteriores ya terminadas (las de la carga)
SELECT recover_prepared_transactions();
SELECT count(*) AS registros_previos FROM pg_dist_transaction;

SET citus.log_remote_commands = on;
SET citus.log_local_commands = on;

BEGIN;
SELECT asignar_tripulante(:t_id_tripulante, :v_id_vuelo, DATE '2026-06-29') AS id_asignacion
\gset a_
COMMIT;

RESET citus.log_remote_commands;
RESET citus.log_local_commands;

-- Registro de la transacción distribuida en el coordinador
SELECT groupid, gid FROM pg_dist_transaction ORDER BY gid;

-- La asignación quedó en los dos workers
SELECT 'asignacion_operacion' AS fragmento, o.id_asignacion, o.id_region, n.nodename
FROM asignacion_operacion o
JOIN pg_dist_placement p ON p.shardid = get_shard_id_for_distribution_column('asignacion_operacion', o.id_region)
JOIN pg_dist_node n USING (groupid)
WHERE o.id_asignacion = :a_id_asignacion
UNION ALL
SELECT 'asignacion_horas', h.id_asignacion, h.id_region, n.nodename
FROM asignacion_horas h
JOIN pg_dist_placement p ON p.shardid = get_shard_id_for_distribution_column('asignacion_horas', h.id_region)
JOIN pg_dist_node n USING (groupid)
WHERE h.id_asignacion = :a_id_asignacion;


-- ---------------------------------------------------------------------
-- 6.4 Validación fallida: el tripulante ya tiene ese vuelo (cruce de horario)
-- ---------------------------------------------------------------------
-- La función aborta antes de escribir; no llega a haber PREPARE y no queda ninguna fila.
-- Los fallos durante el 2PC están en 06b_fallos_2pc.sql.
BEGIN;
SELECT asignar_tripulante(:t_id_tripulante, :v_id_vuelo, DATE '2026-06-29');
ROLLBACK;
