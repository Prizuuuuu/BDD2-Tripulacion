-- =====================================================================
-- Avance 2 - Base de Datos 2 (Septiembre 2026)
-- Grupo 5 - Subsistema Tripulación - Citus 12.1 (PostgreSQL 16)
-- 01. Registro de los workers en el coordinador
-- =====================================================================
-- Ejecutar en el coordinador:
--   docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/01_registrar_nodos.sql

SELECT citus_set_coordinator_host('citus_coordinator', 5432);

-- Credencial para las conexiones internas entre nodos (los repartition joins conectan worker con worker)
INSERT INTO pg_dist_authinfo (nodeid, rolename, authinfo) VALUES (0, 'postgres', 'password=0000');

-- Worker 1 - región ESTE
SELECT master_add_node('citus_worker_1', 5432);
-- Worker 2 - región CENTRAL
SELECT master_add_node('citus_worker_2', 5432);
-- Worker 3 - región OESTE
SELECT master_add_node('citus_worker_3', 5432);

-- La misma credencial en cada worker
SELECT * FROM run_command_on_workers(
    $$INSERT INTO pg_dist_authinfo (nodeid, rolename, authinfo) VALUES (0, 'postgres', 'password=0000')$$);

-- Verificación del registro
SELECT * FROM master_get_active_worker_nodes() ORDER BY node_name;

SELECT nodeid, groupid, nodename, nodeport, noderole, isactive
FROM pg_dist_node
ORDER BY nodeid;
