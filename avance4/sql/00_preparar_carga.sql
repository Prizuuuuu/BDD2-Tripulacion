-- Entrada SQL "Preparar carga" del job: vacía hechos, dimensiones y tablas de paso (la carga es completa)
USE dm_tripulacion;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE fact_asignacion; TRUNCATE TABLE fact_jornada; TRUNCATE TABLE fact_credencial;
TRUNCATE TABLE dim_credencial; TRUNCATE TABLE dim_vuelo; TRUNCATE TABLE dim_tripulante;
TRUNCATE TABLE dim_aeropuerto; TRUNCATE TABLE dim_region; TRUNCATE TABLE dim_tiempo;
TRUNCATE TABLE stg_asignacion; TRUNCATE TABLE stg_jornada; TRUNCATE TABLE stg_credencial; TRUNCATE TABLE etl_rechazos;
SET FOREIGN_KEY_CHECKS = 1;
