@echo off
chcp 65001 >nul
cd /d "%~dp0.."
mode con cols=200 lines=60
title Trazabilidad de la asignacion 66
echo ===== Trazabilidad de la asignacion 66 =====
echo (1) Origen relacional - PostgreSQL staging
docker exec a4_staging_pg psql -U postgres -d tripulacion -c "SELECT a.id_asignacion, a.id_tripulante, a.id_vuelo, a.rol, a.horas_vuelo, v.numero_vuelo, v.fecha_salida_real FROM staging.asignacion_tripulacion a JOIN staging.vuelo v ON v.id_vuelo = a.id_vuelo WHERE a.id_asignacion = 66"
echo (2) Origen NoSQL - Neo4j
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (t:Tripulante)-[:OPERA]->(p:Pairing)-[i:INCLUYE {id_asignacion: 66}]->(v:Vuelo) RETURN t.id_tripulante AS tripulante, p.id_pairing AS pairing, i.orden AS orden, v.id_vuelo AS vuelo, v.equipo AS equipo"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (a)-[r:REEMPLAZADO_POR {id_asignacion: 66}]->(b) RETURN a.id_tripulante AS titular, b.id_tripulante AS sustituto, r.motivo AS motivo, r.aviso_horas AS aviso_horas"
echo (3) Tabla de paso y (4) hecho final - MySQL dm_tripulacion
docker exec -i a4_mysql_dm mysql -uroot -p0000 -t --default-character-set=utf8mb4 -e "SELECT id_asignacion AS asig, id_tripulante AS trip, id_vuelo AS vuelo, fecha_salida, origen, destino, rol, aviso_horas AS aviso, motivo_reemplazo AS motivo FROM dm_tripulacion.stg_asignacion WHERE id_asignacion = 66; SELECT f.id_asignacion AS asig, f.sk_tiempo, f.sk_tripulante AS sk_trip, f.sk_vuelo, v.numero_vuelo AS vuelo, v.ruta, v.equipo, f.es_reemplazo AS reemplazo, f.reemplazo_ultima_hora AS ult_hora, f.aviso_horas AS aviso, f.motivo_reemplazo AS motivo FROM dm_tripulacion.fact_asignacion f JOIN dm_tripulacion.dim_vuelo v ON v.sk_vuelo = f.sk_vuelo WHERE f.id_asignacion = 66;" 2>nul
echo.
timeout /t 40 >nul
