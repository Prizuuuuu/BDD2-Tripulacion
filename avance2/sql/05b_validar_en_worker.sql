-- =====================================================================
-- 05b. Validación directa en cada worker (se ejecuta en el worker, no en el coordinador)
--   docker exec -it citus_worker_1 psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql
--   docker exec -it citus_worker_2 psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql
--   docker exec -it citus_worker_3 psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql
-- =====================================================================
-- Lee las tablas físicas de los shards (nombre_tabla_<shardid>) que existen en este nodo
-- y cuenta las filas por región: cada worker solo debe tener una región.

\echo Nodo:
\! hostname

-- Citus oculta las tablas de los shards en el catálogo; esto las muestra en esta sesión
SET citus.show_shards_for_app_name_prefixes = '*';

SELECT format('SELECT %L AS shard_fisico, id_region, count(*) AS filas FROM %I GROUP BY id_region',
              c.relname, c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname ~ '^(tripulante|certificacion|licencia_medica|jornada_laboral|vuelo|asignacion_operacion|asignacion_horas)_[0-9]+$'
ORDER BY c.relname
\gexec

-- Copias de las tablas de referencia en este nodo
SELECT format('SELECT %L AS shard_referencia, count(*) AS filas FROM %I', c.relname, c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname ~ '^(region|aeropuerto|hub)_[0-9]+$'
ORDER BY c.relname
\gexec
