-- =====================================================================
-- 03. Distribución, asignación de shards y claves foráneas
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Tablas de referencia: copia completa en el coordinador y en los 3 workers
-- ---------------------------------------------------------------------
SELECT create_reference_table('region');
SELECT create_reference_table('aeropuerto');
SELECT create_reference_table('hub');

-- ---------------------------------------------------------------------
-- 3.2 Tablas distribuidas por id_region: 3 shards, uno por región
-- ---------------------------------------------------------------------
SET citus.shard_count = 3;
SET citus.shard_replication_factor = 1;

-- Tabla raíz del grupo de colocación
SELECT create_distributed_table('tripulante', 'id_region');

-- Fragmentos derivados del tripulante
SELECT create_distributed_table('certificacion',    'id_region', colocate_with => 'tripulante');
SELECT create_distributed_table('licencia_medica',  'id_region', colocate_with => 'tripulante');
SELECT create_distributed_table('jornada_laboral',  'id_region', colocate_with => 'tripulante');
SELECT create_distributed_table('asignacion_horas', 'id_region', colocate_with => 'tripulante');

-- Vuelo y su manifiesto (mismo grupo: la región k de vuelo queda en el mismo nodo que la región k de tripulante)
SELECT create_distributed_table('vuelo',                'id_region', colocate_with => 'tripulante');
SELECT create_distributed_table('asignacion_operacion', 'id_region', colocate_with => 'vuelo');

-- tripulante_personal no se distribuye: queda como tabla local del coordinador.

-- ---------------------------------------------------------------------
-- 3.3 Asignación de cada región a su worker
-- ---------------------------------------------------------------------
-- Citus coloca los shards en round-robin. Se mueve cada grupo de shards
-- (todas las tablas colocadas se mueven juntas) al worker que le toca:
--   región 1 ESTE -> citus_worker_1, 2 CENTRAL -> citus_worker_2, 3 OESTE -> citus_worker_3
DO $$
DECLARE
    r        RECORD;
    v_shard  BIGINT;
    v_nodo   TEXT;
BEGIN
    FOR r IN SELECT * FROM (VALUES (1::smallint, 'citus_worker_1'),
                                   (2::smallint, 'citus_worker_2'),
                                   (3::smallint, 'citus_worker_3')) AS d(id_region, destino)
    LOOP
        v_shard := get_shard_id_for_distribution_column('tripulante', r.id_region);

        SELECT n.nodename INTO v_nodo
          FROM pg_dist_placement p
          JOIN pg_dist_node n USING (groupid)
         WHERE p.shardid = v_shard;

        IF v_nodo <> r.destino THEN
            RAISE NOTICE 'Región %: shard % se mueve de % a %', r.id_region, v_shard, v_nodo, r.destino;
            PERFORM citus_move_shard_placement(v_shard, v_nodo, 5432, r.destino, 5432,
                                               shard_transfer_mode => 'block_writes');
        ELSE
            RAISE NOTICE 'Región %: shard % ya está en %', r.id_region, v_shard, v_nodo;
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 3.4 Claves foráneas
-- ---------------------------------------------------------------------
-- Hacia tablas de referencia
ALTER TABLE aeropuerto ADD FOREIGN KEY (id_region)     REFERENCES region (id_region);
ALTER TABLE hub        ADD FOREIGN KEY (id_aeropuerto) REFERENCES aeropuerto (id_aeropuerto);

ALTER TABLE tripulante ADD FOREIGN KEY (id_region)   REFERENCES region (id_region);
ALTER TABLE tripulante ADD FOREIGN KEY (id_hub_base) REFERENCES hub (id_hub);

ALTER TABLE vuelo ADD FOREIGN KEY (id_region)             REFERENCES region (id_region);
ALTER TABLE vuelo ADD FOREIGN KEY (id_aeropuerto_origen)  REFERENCES aeropuerto (id_aeropuerto);
ALTER TABLE vuelo ADD FOREIGN KEY (id_aeropuerto_destino) REFERENCES aeropuerto (id_aeropuerto);

-- Entre tablas colocadas: deben incluir la columna de distribución
ALTER TABLE certificacion    ADD FOREIGN KEY (id_tripulante, id_region) REFERENCES tripulante (id_tripulante, id_region);
ALTER TABLE licencia_medica  ADD FOREIGN KEY (id_tripulante, id_region) REFERENCES tripulante (id_tripulante, id_region);
ALTER TABLE jornada_laboral  ADD FOREIGN KEY (id_tripulante, id_region) REFERENCES tripulante (id_tripulante, id_region);
ALTER TABLE asignacion_horas ADD FOREIGN KEY (id_tripulante, id_region) REFERENCES tripulante (id_tripulante, id_region);

ALTER TABLE asignacion_operacion ADD FOREIGN KEY (id_vuelo, id_region) REFERENCES vuelo (id_vuelo, id_region);

-- No se pueden declarar (quedan a cargo del procedimiento de 06):
--   asignacion_horas.id_asignacion -> asignacion_operacion (regiones distintas)
--   tripulante_personal -> tripulante (tabla local hacia tabla distribuida)

-- ---------------------------------------------------------------------
-- 3.5 Verificación del tipo de cada tabla
-- ---------------------------------------------------------------------
SELECT logicalrelid::regclass AS tabla, partmethod, colocationid, repmodel
FROM pg_dist_partition
ORDER BY colocationid, logicalrelid::regclass::text;

SELECT table_name, citus_table_type, distribution_column, colocation_id, shard_count
FROM citus_tables
ORDER BY colocation_id, table_name;
