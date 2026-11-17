@echo off
chcp 65001 >nul
cd /d "%~dp0.."
echo Levantando PostgreSQL, Neo4j, MySQL y Metabase (log en pc\log_entorno.txt)...
call :main > "%~dp0log_entorno.txt" 2>&1
echo Terminado. Revisa pc\log_entorno.txt
exit /b

:main
docker compose up -d
echo == Esperando PostgreSQL (staging)
:pg
timeout /t 5 /nobreak >nul
docker exec a4_staging_pg psql -U postgres -d tripulacion -tAc "select count(*) from staging.asignacion_tripulacion" || goto pg
echo == Esperando MySQL
:my
timeout /t 5 /nobreak >nul
docker exec a4_mysql_dm mysql -uroot -p0000 -e "select count(*) from information_schema.tables where table_schema='dm_tripulacion'" || goto my
echo == Esperando Neo4j
:neo
timeout /t 5 /nobreak >nul
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "RETURN 1" || goto neo
echo == Cargando el grafo de la Unidad 3
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /scripts/00_indices_community.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (n) RETURN count(n) AS nodos_antes"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /cypher/02_nodos.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /cypher/03_relaciones.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (n) RETURN count(n) AS nodos"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH ()-[r]->() RETURN count(r) AS relaciones"
echo == Exportando Neo4j a CSV
docker run --rm --network avance4_default -v "%cd%\etl:/etl" -e NEO4J_URI=bolt://a4_neo4j:7687 python:3.12-slim sh -c "pip install -q neo4j && python /etl/exportar_neo4j.py"
echo ENTORNO_OK
exit /b
