@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Extraccion NoSQL - exportar_neo4j.py
echo ===== Extraccion NoSQL - exportar_neo4j.py =====
docker run --rm --network avance4_default -v "%cd%\etl:/etl" -e NEO4J_URI=bolt://a4_neo4j:7687 python:3.12-slim sh -c "pip install -q --root-user-action=ignore --disable-pip-version-check neo4j && python /etl/exportar_neo4j.py"
echo.
timeout /t 40 >nul
