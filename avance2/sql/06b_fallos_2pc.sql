-- =====================================================================
-- 06b. Fallos durante el 2PC: atomicidad global y recuperación
-- =====================================================================

-- ---------------------------------------------------------------------
-- Escenario A: un participante falla durante la fase de preparación
-- ---------------------------------------------------------------------
-- Se hace con dos terminales.
--
-- Terminal 1 (coordinador):
--   docker exec -it citus_coordinator psql -U postgres -d coorddb
--
--   SET citus.log_remote_commands = on;
--   BEGIN;
--   SELECT asignar_tripulante(1, (SELECT id_vuelo FROM vuelo WHERE numero_vuelo = 'AA2PC1'), DATE '2026-06-29');
--   -- (no confirmar todavía)
--
-- Terminal 2 (PowerShell, carpeta avance2):
--   docker stop citus_worker_1
--
-- Terminal 1:
--   COMMIT;
--   -- El coordinador envía PREPARE TRANSACTION a los dos workers. El worker 2 prepara su parte,
--   -- el worker 1 no responde: el coordinador aborta y envía ROLLBACK PREPARED al worker 2.
--
-- Terminal 2:
--   docker start citus_worker_1
--
-- Verificación: la asignación no quedó en ningún nodo y no hay transacciones preparadas pendientes
SELECT 'asignacion_horas' AS fragmento, count(*) AS filas
FROM asignacion_horas
WHERE id_tripulante = 1 AND id_region = 1 AND id_asignacion > 5500
UNION ALL
SELECT 'asignacion_operacion', count(*)
FROM asignacion_operacion o
JOIN vuelo v ON v.id_vuelo = o.id_vuelo AND v.id_region = o.id_region
WHERE v.numero_vuelo = 'AA2PC1' AND o.rol = 'COPILOTO';

SELECT * FROM run_command_on_workers('SELECT count(*) FROM pg_prepared_xacts');


-- ---------------------------------------------------------------------
-- Escenario B: el coordinador cae entre la recolección de votos y la decisión
-- ---------------------------------------------------------------------
-- Se simulan dos participantes que votaron sí (quedaron en PREPARED) y no recibieron la decisión.
-- Parte 1, en el worker 2:
--   docker exec -it citus_worker_2 psql -U postgres -d coorddb
--
--   SET citus.show_shards_for_app_name_prefixes = '*';
--   BEGIN;
--   INSERT INTO asignacion_operacion_102031 (id_asignacion, id_region, id_vuelo, fecha_asignacion, rol)
--   VALUES (900001, 2, 1101, '2026-06-29', 'AUXILIAR_VUELO');
--   PREPARE TRANSACTION 'citus_0_99001_1_1';
--   BEGIN;
--   INSERT INTO asignacion_operacion_102031 (id_asignacion, id_region, id_vuelo, fecha_asignacion, rol)
--   VALUES (900002, 2, 1101, '2026-06-29', 'AUXILIAR_VUELO');
--   PREPARE TRANSACTION 'citus_0_99002_1_1';
--
--   SELECT gid, prepared FROM pg_prepared_xacts;   -- 2 transacciones en estado preparado
--   SELECT count(*) FROM asignacion_operacion_102031 WHERE id_asignacion IN (900001, 900002);  -- 0: no son visibles
--
-- Parte 2, en el coordinador (al "recuperarse"):
-- Solo la transacción 99002 alcanzó a registrar la decisión de COMMIT en el log del coordinador
INSERT INTO pg_dist_transaction (groupid, gid) VALUES (2, 'citus_0_99002_1_1');

SELECT groupid, gid FROM pg_dist_transaction WHERE gid LIKE 'citus_0_990%';

-- Protocolo de recuperación: COMMIT PREPARED si hay registro, ROLLBACK PREPARED si no lo hay
SELECT recover_prepared_transactions();

SELECT id_asignacion, id_region, rol
FROM asignacion_operacion
WHERE id_asignacion IN (900001, 900002);   -- solo queda la 900002

SELECT * FROM run_command_on_workers('SELECT count(*) FROM pg_prepared_xacts');

-- Limpieza de la fila de prueba
DELETE FROM asignacion_operacion WHERE id_asignacion = 900002 AND id_region = 2;
