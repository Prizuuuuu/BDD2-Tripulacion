@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Validacion de metricas M1 a M3 (MySQL)
echo ===== Validacion de metricas M1 a M3 (MySQL) =====
docker exec -i a4_mysql_dm mysql -uroot -p0000 -t --default-character-set=utf8mb4 < sql\val_a.sql 2>nul
echo.
timeout /t 40 >nul
