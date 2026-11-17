@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Calidad de datos - staging PostgreSQL (puerto 5440)
echo ===== Calidad de datos - staging PostgreSQL (puerto 5440) =====
docker exec -i a4_staging_pg psql -U postgres -d tripulacion -P pager=off < sql\06_calidad_origen.sql
echo.
timeout /t 40 >nul
