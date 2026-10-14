-- =====================================================================
-- 05. Verificación de shards, nodos y tamaños
-- =====================================================================

-- 5.1 Tipo de cada tabla (h = hash/distribuida, n = referencia)
SELECT logicalrelid::regclass AS tabla, partmethod, colocationid, repmodel
FROM pg_dist_partition
ORDER BY colocationid, logicalrelid::regclass::text;

-- 5.2 Shards y nodos de cada tabla (pg_dist_shard + pg_dist_placement)
SELECT s.logicalrelid::regclass AS tabla,
       s.shardid,
       s.shardminvalue,
       s.shardmaxvalue,
       n.nodename,
       p.placementid
FROM pg_dist_shard s
JOIN pg_dist_placement p USING (shardid)
JOIN pg_dist_node n USING (groupid)
ORDER BY s.logicalrelid::regclass::text, n.nodename;

-- 5.3 Región que guarda cada shard (una región por worker)
SELECT r.id_region,
       r.nombre_region,
       get_shard_id_for_distribution_column('tripulante', r.id_region) AS shard_tripulante,
       n.nodename
FROM region r
JOIN pg_dist_placement p ON p.shardid = get_shard_id_for_distribution_column('tripulante', r.id_region)
JOIN pg_dist_node n USING (groupid)
ORDER BY r.id_region;

-- 5.4 Número de shards y tamaño por nodo (desbalance entre regiones)
SELECT nodename,
       count(*)                                  AS shards,
       pg_size_pretty(sum(shard_size))           AS tamano_total,
       sum(shard_size)                           AS bytes
FROM citus_shards
WHERE citus_table_type = 'distributed'
GROUP BY nodename
ORDER BY nodename;

-- 5.5 Tamaño de cada shard por tabla y nodo
SELECT table_name, nodename, shardid, pg_size_pretty(shard_size) AS tamano, shard_size
FROM citus_shards
WHERE citus_table_type = 'distributed'
ORDER BY table_name, nodename;

-- 5.6 Filas por región (desbalance 6 / 2 / 2 hubs)
WITH conteo AS (
    SELECT 'tripulante' AS tabla, id_region, count(*) AS filas FROM tripulante GROUP BY id_region
    UNION ALL SELECT 'certificacion', id_region, count(*) FROM certificacion GROUP BY id_region
    UNION ALL SELECT 'licencia_medica', id_region, count(*) FROM licencia_medica GROUP BY id_region
    UNION ALL SELECT 'jornada_laboral', id_region, count(*) FROM jornada_laboral GROUP BY id_region
    UNION ALL SELECT 'vuelo', id_region, count(*) FROM vuelo GROUP BY id_region
    UNION ALL SELECT 'asignacion_operacion', id_region, count(*) FROM asignacion_operacion GROUP BY id_region
    UNION ALL SELECT 'asignacion_horas', id_region, count(*) FROM asignacion_horas GROUP BY id_region
)
SELECT tabla,
       sum(filas) FILTER (WHERE id_region = 1) AS este,
       sum(filas) FILTER (WHERE id_region = 2) AS central,
       sum(filas) FILTER (WHERE id_region = 3) AS oeste,
       sum(filas)                              AS total
FROM conteo
GROUP BY tabla
ORDER BY tabla;

-- 5.7 Tablas de referencia: una copia en cada nodo (incluido el coordinador)
SELECT table_name, nodename, shardid, shard_size
FROM citus_shards
WHERE citus_table_type = 'reference'
ORDER BY table_name, nodename;
