@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Data Mart dm_tripulacion - conteo de filas (MySQL 8.0)
echo ===== Data Mart dm_tripulacion - conteo de filas (MySQL 8.0) =====
docker exec -i a4_mysql_dm mysql -uroot -p0000 -t --default-character-set=utf8mb4 -e "USE dm_tripulacion; SELECT 'dim_tiempo' tabla, COUNT(*) filas FROM dim_tiempo UNION ALL SELECT 'dim_region',COUNT(*) FROM dim_region UNION ALL SELECT 'dim_aeropuerto',COUNT(*) FROM dim_aeropuerto UNION ALL SELECT 'dim_tripulante',COUNT(*) FROM dim_tripulante UNION ALL SELECT 'dim_vuelo',COUNT(*) FROM dim_vuelo UNION ALL SELECT 'dim_credencial',COUNT(*) FROM dim_credencial UNION ALL SELECT 'fact_asignacion',COUNT(*) FROM fact_asignacion UNION ALL SELECT 'fact_jornada',COUNT(*) FROM fact_jornada UNION ALL SELECT 'fact_credencial',COUNT(*) FROM fact_credencial; SELECT SUM(horas_vuelo) AS horas_dm FROM fact_asignacion;" 2>nul
docker exec a4_staging_pg psql -U postgres -d tripulacion -c "SELECT count(*) AS asignaciones_staging, sum(horas_vuelo) AS horas_staging FROM staging.asignacion_tripulacion"
echo.
timeout /t 40 >nul
