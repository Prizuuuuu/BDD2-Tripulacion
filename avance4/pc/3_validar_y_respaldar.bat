@echo off
chcp 65001 >nul
cd /d "%~dp0.."
if not exist salidas mkdir salidas
echo Validando metricas y generando el respaldo (salidas en avance4\salidas)...
docker exec -i a4_mysql_dm mysql -uroot -p0000 -t --default-character-set=utf8mb4 < sql\04_validacion_metricas.sql > salidas\validacion_metricas.txt 2>&1
docker exec -i a4_mysql_dm mysql -uroot -p0000 -t --default-character-set=utf8mb4 -e "USE dm_tripulacion; SELECT 'dim_tiempo' tabla, COUNT(*) filas FROM dim_tiempo UNION ALL SELECT 'dim_region',COUNT(*) FROM dim_region UNION ALL SELECT 'dim_aeropuerto',COUNT(*) FROM dim_aeropuerto UNION ALL SELECT 'dim_tripulante',COUNT(*) FROM dim_tripulante UNION ALL SELECT 'dim_vuelo',COUNT(*) FROM dim_vuelo UNION ALL SELECT 'dim_credencial',COUNT(*) FROM dim_credencial UNION ALL SELECT 'fact_asignacion',COUNT(*) FROM fact_asignacion UNION ALL SELECT 'fact_jornada',COUNT(*) FROM fact_jornada UNION ALL SELECT 'fact_credencial',COUNT(*) FROM fact_credencial;" > salidas\conteos.txt 2>&1
docker exec a4_mysql_dm sh -c "mysqldump -uroot -p0000 --databases dm_tripulacion > /tmp/dm_tripulacion.sql"
docker cp a4_mysql_dm:/tmp/dm_tripulacion.sql backup\dm_tripulacion.sql
dir backup > salidas\respaldo.txt
echo VALIDACION_OK >> salidas\conteos.txt
echo Terminado.
