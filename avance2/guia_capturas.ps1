# =====================================================================
# Guía de capturas - Avance 2 - Grupo 5 Tripulación
# Uso (PowerShell, en la carpeta avance2):
#   powershell -ExecutionPolicy Bypass -File .\guia_capturas.ps1
# Reconstruye el clúster desde cero y se detiene después de cada paso
# para tomar la captura (Win + Shift + S). Maximizar la ventana antes de empezar.
# =====================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$env:Path += ";C:\Program Files\Docker\Docker\resources\bin"
Set-Location $PSScriptRoot

function Paso($codigo, $titulo) {
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host " $codigo  $titulo" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
}
function Comando($texto) { Write-Host "PS> $texto" -ForegroundColor Yellow }
function Captura($codigo) {
    Write-Host ""
    if ($env:GUIA_AUTO) { return }
    Read-Host "Toma la captura $codigo y presiona Enter para continuar"
}
function Coord($archivo) {
    Comando "docker exec -it citus_coordinator psql -U postgres -d coorddb -f $archivo"
    docker exec citus_coordinator psql -U postgres -d coorddb -e -f $archivo 2>&1 | ForEach-Object { "$_" }
}
function CoordSql($sql) {
    Comando "docker exec -it citus_coordinator psql -U postgres -d coorddb"
    $sql | docker exec -i citus_coordinator psql -U postgres -d coorddb -e 2>&1 | ForEach-Object { "$_" }
}

# ---------------------------------------------------------------------
Paso "C1" "Levantar el clúster (docker-compose up -d)"
Comando "docker-compose down -v"
docker compose down -v 2>&1 | ForEach-Object { "$_" }
Comando "docker-compose up -d"
docker compose up -d 2>&1 | ForEach-Object { "$_" }
Write-Host "Esperando a que los contenedores estén listos..." -ForegroundColor DarkGray
Start-Sleep -Seconds 20
Comando "docker ps"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
Captura "C1"

Paso "C2" "Docker Desktop"
Write-Host "Abre Docker Desktop > Containers y despliega el grupo 'avance2':" -ForegroundColor Green
Write-Host "deben verse citus_coordinator, citus_worker_1, citus_worker_2 y citus_worker_3 en verde." -ForegroundColor Green
Captura "C2"

Paso "C3" "Extensión Citus instalada por el script de inicio (00_enable_citus.sql)"
Comando "Get-Content .\init\init_citus\coord\00_enable_citus.sql"
Get-Content .\init\init_citus\coord\00_enable_citus.sql -Encoding UTF8
CoordSql "\dx citus"
Comando 'docker exec -it citus_worker_1 psql -U postgres -d coorddb -c "\dx citus"'
docker exec citus_worker_1 psql -U postgres -d coorddb -c "\dx citus"
Captura "C3"

Paso "C4" "Registro de los workers en el coordinador (01_registrar_nodos.sql)"
Coord "/sql/01_registrar_nodos.sql"
Captura "C4"

Paso "C5" "Staging central: base de la Unidad 1 en el esquema staging"
Comando "docker exec -i citus_coordinator psql -U postgres -d coorddb -f /staging/tripulacion_staging.sql"
docker exec citus_coordinator psql -U postgres -d coorddb -q -f /staging/tripulacion_staging.sql -o /dev/null 2>&1 | Out-Null
CoordSql "\dt staging.*
SELECT 'asignacion_tripulacion' AS tabla, count(*) FROM staging.asignacion_tripulacion
UNION ALL SELECT 'tripulante', count(*) FROM staging.tripulante
UNION ALL SELECT 'vuelo', count(*) FROM staging.vuelo;"
Captura "C5"

Paso "C6" "Esquema distribuido (02_esquema_distribuido.sql)"
docker exec citus_coordinator psql -U postgres -d coorddb -q -f /sql/02_esquema_distribuido.sql 2>&1 | Out-Null
Comando "docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/02_esquema_distribuido.sql"
CoordSql "\dt public.*
\d asignacion_horas"
Captura "C6"

Paso "C7" "Tablas de referencia, tablas distribuidas y asignación de cada región a su worker (03_distribucion.sql)"
Coord "/sql/03_distribucion.sql" | Select-Object -First 75
Captura "C7"

Paso "C8" "Tipo de cada tabla en el catálogo (pg_dist_partition y citus_tables)"
CoordSql "SELECT logicalrelid::regclass AS tabla, partmethod, colocationid, repmodel
FROM pg_dist_partition ORDER BY colocationid, logicalrelid::regclass::text;
SELECT table_name, citus_table_type, distribution_column, colocation_id, shard_count
FROM citus_tables ORDER BY colocation_id, table_name;"
Captura "C8"

Paso "C9" "Carga desde el staging y conteo staging vs distribuido (04_carga_desde_staging.sql)"
docker exec citus_coordinator psql -U postgres -d coorddb -q -f /sql/04_carga_desde_staging.sql -o /dev/null 2>&1 | Out-Null
Comando "docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/04_carga_desde_staging.sql"
CoordSql "SELECT 'tripulante' AS tabla, (SELECT count(*) FROM staging.tripulante) AS staging, (SELECT count(*) FROM tripulante) AS distribuido
UNION ALL SELECT 'tripulante_personal', (SELECT count(*) FROM staging.tripulante), (SELECT count(*) FROM tripulante_personal)
UNION ALL SELECT 'certificacion', (SELECT count(*) FROM staging.certificacion), (SELECT count(*) FROM certificacion)
UNION ALL SELECT 'licencia_medica', (SELECT count(*) FROM staging.licencia_medica), (SELECT count(*) FROM licencia_medica)
UNION ALL SELECT 'jornada_laboral', (SELECT count(*) FROM staging.jornada_laboral), (SELECT count(*) FROM jornada_laboral)
UNION ALL SELECT 'vuelo', (SELECT count(*) FROM staging.vuelo), (SELECT count(*) FROM vuelo)
UNION ALL SELECT 'asignacion_operacion', (SELECT count(*) FROM staging.asignacion_tripulacion), (SELECT count(*) FROM asignacion_operacion)
UNION ALL SELECT 'asignacion_horas', (SELECT count(*) FROM staging.asignacion_tripulacion), (SELECT count(*) FROM asignacion_horas)
UNION ALL SELECT 'region', (SELECT count(*) FROM staging.region), (SELECT count(*) FROM region)
UNION ALL SELECT 'aeropuerto', (SELECT count(*) FROM staging.aeropuerto), (SELECT count(*) FROM aeropuerto)
UNION ALL SELECT 'hub', (SELECT count(*) FROM staging.hub), (SELECT count(*) FROM hub);"
Captura "C9"

Paso "C10" "Shards y nodos: pg_dist_shard + pg_dist_placement"
CoordSql "SELECT s.logicalrelid::regclass AS tabla, s.shardid, s.shardminvalue, s.shardmaxvalue, n.nodename
FROM pg_dist_shard s
JOIN pg_dist_placement p USING (shardid)
JOIN pg_dist_node n USING (groupid)
WHERE s.logicalrelid IN ('tripulante'::regclass, 'vuelo'::regclass, 'asignacion_operacion'::regclass, 'asignacion_horas'::regclass)
ORDER BY n.nodename, s.logicalrelid::regclass::text;
SELECT r.id_region, r.nombre_region,
       get_shard_id_for_distribution_column('tripulante', r.id_region) AS shard_tripulante, n.nodename
FROM region r
JOIN pg_dist_placement p ON p.shardid = get_shard_id_for_distribution_column('tripulante', r.id_region)
JOIN pg_dist_node n USING (groupid)
ORDER BY r.id_region;"
Captura "C10"

Paso "C11" "Número de shards y tamaño por nodo (desbalance)"
CoordSql "SELECT nodename, count(*) AS shards, pg_size_pretty(sum(shard_size)) AS tamano_total
FROM citus_shards WHERE citus_table_type = 'distributed' GROUP BY nodename ORDER BY nodename;
SELECT table_name, nodename, shardid, pg_size_pretty(shard_size) AS tamano
FROM citus_shards WHERE citus_table_type = 'distributed' ORDER BY table_name, nodename;"
Captura "C11"

Paso "C12" "Filas por región y copias de las tablas de referencia"
CoordSql "WITH conteo AS (
    SELECT 'tripulante' AS tabla, id_region, count(*) AS filas FROM tripulante GROUP BY id_region
    UNION ALL SELECT 'certificacion', id_region, count(*) FROM certificacion GROUP BY id_region
    UNION ALL SELECT 'licencia_medica', id_region, count(*) FROM licencia_medica GROUP BY id_region
    UNION ALL SELECT 'jornada_laboral', id_region, count(*) FROM jornada_laboral GROUP BY id_region
    UNION ALL SELECT 'vuelo', id_region, count(*) FROM vuelo GROUP BY id_region
    UNION ALL SELECT 'asignacion_operacion', id_region, count(*) FROM asignacion_operacion GROUP BY id_region
    UNION ALL SELECT 'asignacion_horas', id_region, count(*) FROM asignacion_horas GROUP BY id_region)
SELECT tabla, sum(filas) FILTER (WHERE id_region = 1) AS este, sum(filas) FILTER (WHERE id_region = 2) AS central,
       sum(filas) FILTER (WHERE id_region = 3) AS oeste, sum(filas) AS total
FROM conteo GROUP BY tabla ORDER BY tabla;
SELECT table_name, nodename, shardid FROM citus_shards WHERE citus_table_type = 'reference' ORDER BY table_name, nodename;"
Captura "C12"

foreach ($w in 1, 2, 3) {
    Paso "C1$(2 + $w)" "Validación directa en citus_worker_$w (05b_validar_en_worker.sql)"
    Comando "docker exec -it citus_worker_$w psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql"
    docker exec citus_worker_$w psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql 2>&1 | ForEach-Object { "$_" }
    Captura "C1$(2 + $w)"
}

Paso "C16" "Reconstrucción, completitud y disyunción contra el staging (05c_reconstruccion.sql)"
Coord "/sql/05c_reconstruccion.sql" | Select-String -NotMatch "WARNING|DETAIL|HINT" | ForEach-Object { "$_" }
Captura "C16"

Paso "C17" "Transacción distribuida 2PC: mensajes del coordinador (06_transaccion_2pc.sql)"
$t06 = docker exec citus_coordinator psql -U postgres -d coorddb -f /sql/06_transaccion_2pc.sql 2>&1 | ForEach-Object { "$_" }
Comando "docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/06_transaccion_2pc.sql"
$mostrar = $false
foreach ($linea in $t06) {
    if ($linea -match "Tripulante .* -> vuelo|issuing (INSERT|PREPARE|COMMIT|ROLLBACK)|^COMMIT$") {
        $linea -replace "^psql:/sql/06_transaccion_2pc.sql:\d+: ", ""
        $mostrar = $linea -match "issuing"
    } elseif ($mostrar -and $linea -match "^DETAIL") {
        $linea
        $mostrar = $false
    } else {
        $mostrar = $false
    }
}
Captura "C17"

Paso "C18" "Registro en pg_dist_transaction y ubicación de la asignación en los dos workers"
$i = [array]::IndexOf($t06, ($t06 | Where-Object { $_ -match "groupid \| " } | Select-Object -First 1))
$t06[($i - 1)..($t06.Count - 1)]
Captura "C18"

Paso "C19" "Fallo de un participante durante el PREPARE (06b, escenario A)"
$vuelo = (docker exec citus_coordinator psql -U postgres -d coorddb -tAc "SELECT id_vuelo FROM vuelo WHERE numero_vuelo = 'AA2PC1'").Trim()
$job = Start-Job -ScriptBlock {
    $env:Path += ";C:\Program Files\Docker\Docker\resources\bin"
    Start-Sleep -Seconds 5
    docker stop citus_worker_1 | Out-Null
}
Comando "BEGIN; SELECT asignar_tripulante(1, $vuelo, '2026-06-29');  ... (en otra terminal: docker stop citus_worker_1) ...  COMMIT;"
"SET citus.log_remote_commands = on;
BEGIN;
SELECT asignar_tripulante(1, $vuelo, DATE '2026-06-29') AS id_asignacion;
SELECT pg_sleep(10);
COMMIT;" | docker exec -i citus_coordinator psql -U postgres -d coorddb -e 2>&1 |
    ForEach-Object { "$_" } | Select-String -NotMatch "issuing SELECT|issuing BEGIN|^DETAIL|executing the command locally|read_intermediate_result|^'20|^\s*$|RemoteException" |
    ForEach-Object { $_.Line }
Wait-Job $job | Out-Null
Write-Host "PS> docker stop citus_worker_1   (ejecutado durante la transacción)" -ForegroundColor Yellow
Captura "C19"

Paso "C20" "Después del fallo: el worker vuelve y no quedó nada parcial"
Comando "docker start citus_worker_1"
docker start citus_worker_1
Start-Sleep -Seconds 8
CoordSql "SELECT 'asignacion_horas (worker 1)' AS fragmento, count(*) AS filas FROM asignacion_horas
WHERE id_tripulante = 1 AND id_region = 1 AND id_asignacion > 5500
UNION ALL
SELECT 'asignacion_operacion (worker 2)', count(*) FROM asignacion_operacion
WHERE id_vuelo = $vuelo AND id_region = 2 AND rol = 'COPILOTO';
SELECT * FROM run_command_on_workers('SELECT count(*) FROM pg_prepared_xacts');"
Captura "C20"

Paso "C21" "Caída del coordinador entre los votos y la decisión (06b, escenario B): participantes en PREPARED"
Comando "docker exec -it citus_worker_2 psql -U postgres -d coorddb"
"SET citus.show_shards_for_app_name_prefixes = '*';
BEGIN;
INSERT INTO asignacion_operacion_102031 (id_asignacion, id_region, id_vuelo, fecha_asignacion, rol)
VALUES (900001, 2, $vuelo, '2026-06-29', 'AUXILIAR_VUELO');
PREPARE TRANSACTION 'citus_0_99001_1_1';
BEGIN;
INSERT INTO asignacion_operacion_102031 (id_asignacion, id_region, id_vuelo, fecha_asignacion, rol)
VALUES (900002, 2, $vuelo, '2026-06-29', 'AUXILIAR_VUELO');
PREPARE TRANSACTION 'citus_0_99002_1_1';
SELECT gid, prepared FROM pg_prepared_xacts;
SELECT count(*) AS visibles FROM asignacion_operacion_102031 WHERE id_asignacion IN (900001, 900002);" |
    docker exec -i citus_worker_2 psql -U postgres -d coorddb -e 2>&1 | ForEach-Object { "$_" }
Captura "C21"

Paso "C22" "Recuperación del coordinador: COMMIT si registró la decisión, ROLLBACK si no"
CoordSql "INSERT INTO pg_dist_transaction (groupid, gid) VALUES (2, 'citus_0_99002_1_1');
SELECT groupid, gid FROM pg_dist_transaction WHERE gid LIKE 'citus_0_990%';
SELECT recover_prepared_transactions();
SELECT id_asignacion, id_region, rol FROM asignacion_operacion WHERE id_asignacion IN (900001, 900002);
SELECT * FROM run_command_on_workers('SELECT count(*) FROM pg_prepared_xacts');
DELETE FROM asignacion_operacion WHERE id_asignacion = 900002 AND id_region = 2;"
Captura "C22"

# ---------------------------------------------------------------------
$q1 = "SELECT r.nombre_region, a.codigo_iata AS base, count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN tripulante t  ON t.id_tripulante = h.id_tripulante{0}
JOIN hub hb        ON hb.id_hub = t.id_hub_base
JOIN aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN region r      ON r.id_region = t.id_region{1}
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;"
$rep = "SET citus.enable_repartition_joins = on;
SET citus.multi_shard_modify_mode TO 'sequential';"

Paso "C23" "Consulta 1, estrategia co-located join + tablas de referencia"
CoordSql ("SET citus.explain_all_tasks = on;`nEXPLAIN (ANALYZE)`n" + ($q1 -f " AND t.id_region = h.id_region", ""))
Captura "C23 (si no cabe, toma dos capturas: C23a y C23b)"

Paso "C24" "Consulta 1, estrategia repartition join"
CoordSql ($rep + "`nEXPLAIN (ANALYZE)`n" + ($q1 -f "", ""))
Captura "C24"

Paso "C25" "Consulta 1, estrategia router (solo la región ESTE)"
CoordSql ("EXPLAIN (ANALYZE)`n" + ($q1 -f " AND t.id_region = h.id_region", "`nWHERE h.id_region = 1"))
Captura "C25"

Paso "C26" "Consulta 1 sobre el staging central (Unidad 1) y resultado"
CoordSql "EXPLAIN (ANALYZE)
SELECT r.nombre_region, a.codigo_iata AS base, count(*) AS asignaciones, sum(x.horas_vuelo) AS horas_vuelo
FROM staging.asignacion_tripulacion x
JOIN staging.tripulante t  ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb        ON hb.id_hub = t.id_hub_base
JOIN staging.aeropuerto a  ON a.id_aeropuerto = hb.id_aeropuerto
JOIN staging.region r      ON r.id_region = a.id_region
GROUP BY r.nombre_region, a.codigo_iata
ORDER BY r.nombre_region, base;"
Captura "C26"

Paso "C27" "Resultado de la consulta 1: horas de vuelo acumuladas por base operativa"
CoordSql ($q1 -f " AND t.id_region = h.id_region", "")
Captura "C27"

$q2 = "SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h
JOIN asignacion_operacion o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region
JOIN region ro ON ro.id_region = o.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;"

Paso "C28" "Consulta 2, estrategia repartition join"
CoordSql ($rep + "`nEXPLAIN (ANALYZE)`n" + $q2)
Captura "C28"

Paso "C29" "Consulta 2, estrategia gather en el coordinador"
CoordSql "EXPLAIN (ANALYZE)
WITH h AS MATERIALIZED (SELECT id_asignacion, id_region, horas_vuelo FROM asignacion_horas),
     o AS MATERIALIZED (SELECT id_asignacion, id_region FROM asignacion_operacion)
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM h
JOIN o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region
JOIN region ro ON ro.id_region = o.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;"
Captura "C29 (si no cabe, toma dos capturas: C29a y C29b)"

Paso "C30" "Consulta 2 sobre el staging central y resultado distribuido"
CoordSql ("EXPLAIN (ANALYZE)
SELECT rb.nombre_region AS region_base, ro.nombre_region AS region_vuelo,
       count(*) AS asignaciones, sum(x.horas_vuelo) AS horas_vuelo
FROM staging.asignacion_tripulacion x
JOIN staging.tripulante t   ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb         ON hb.id_hub = t.id_hub_base
JOIN staging.aeropuerto ab  ON ab.id_aeropuerto = hb.id_aeropuerto
JOIN staging.vuelo v        ON v.id_vuelo = x.id_vuelo
JOIN staging.aeropuerto av  ON av.id_aeropuerto = v.id_aeropuerto_origen
JOIN staging.region rb      ON rb.id_region = ab.id_region
JOIN staging.region ro      ON ro.id_region = av.id_region
GROUP BY rb.nombre_region, ro.nombre_region
ORDER BY 1, 2;
" + $rep + "`n" + $q2)
Captura "C30"

Clear-Host
Write-Host "Listo: 30 capturas. El clúster queda encendido; para apagarlo: docker-compose down" -ForegroundColor Green
