@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Calidad en Neo4j - cypher-shell
echo ===== Calidad en Neo4j - cypher-shell =====
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH ()-[c:CONECTA_CON]->() RETURN c.mismo_aeropuerto AS mismo_aeropuerto, count(*) AS conexiones ORDER BY mismo_aeropuerto"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (:Pairing)-[i:INCLUYE {orden: 1}]->(:Vuelo) RETURN count(i) AS tramos_sin_descanso_previo"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (h:Habilitacion) WHERE h.fecha_vencimiento IS NULL RETURN h.tipo AS tipo, h.estado AS estado, count(*) AS sin_vencimiento"
echo.
timeout /t 40 >nul
