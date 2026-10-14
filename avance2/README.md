# Avance 2 · Grupo 5 · Subsistema Tripulación (Citus 12.1)

Base de datos distribuida del subsistema Tripulación: 1 coordinador y 3 workers, uno por región
(ESTE, CENTRAL, OESTE), con la base de la Unidad 1 como staging central.

## Requisitos

- Docker Desktop (con WSL 2 en Windows) y unos 4 GB de RAM libres.
- La imagen `citusdata/citus:12.1` (se descarga sola con el primer `docker-compose up`).

## Contenido

| Ruta | Qué es |
|---|---|
| `docker-compose.yaml` | Coordinador (puerto 5437) y 3 workers en la red `citusnet`, con volúmenes persistentes |
| `init/init_citus/coord`, `init/init_citus/worker` | `00_enable_citus.sql`: instala la extensión Citus al crear cada contenedor |
| `staging/tripulacion_staging.sql` | Respaldo de la Unidad 1 (`tripulacion_final.sql`) en el esquema `staging` |
| `sql/01_registrar_nodos.sql` | Registra los workers (`master_add_node`) y la credencial interna (`pg_dist_authinfo`) |
| `sql/02_esquema_distribuido.sql` | Tablas con `id_region` y fragmentos verticales |
| `sql/03_distribucion.sql` | Tablas de referencia y distribuidas, cada región a su worker y claves foráneas |
| `sql/04_carga_desde_staging.sql` | Carga de los fragmentos desde el staging y conteo |
| `sql/05_verificacion_shards.sql` | `pg_dist_shard`, `pg_dist_placement`, shards y tamaños por nodo |
| `sql/05b_validar_en_worker.sql` | Se ejecuta dentro de cada worker: filas por región en sus shards |
| `sql/05c_reconstruccion.sql` | Reconstrucción, completitud y disyunción contra el staging |
| `sql/06_transaccion_2pc.sql` | Procedimiento `asignar_tripulante` y transacción 2PC entre dos regiones |
| `sql/06b_fallos_2pc.sql` | Fallo de un participante y recuperación tras la caída del coordinador |
| `sql/07_consultas_distribuidas.sql` | Co-located, repartition, router, gather y staging con `EXPLAIN ANALYZE` |
| `mediciones/` | Script de medición (15 ejecuciones por estrategia) y resultados |
| `guia_capturas.ps1` | Reproduce todo el proceso desde cero, paso a paso |
| `capturas/` | Capturas C1 a C30 del informe |

## Cómo ejecutarlo

Desde esta carpeta, en PowerShell:

```
docker-compose up -d
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/01_registrar_nodos.sql
docker exec -i  citus_coordinator psql -U postgres -d coorddb -f /staging/tripulacion_staging.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/02_esquema_distribuido.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/03_distribucion.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/04_carga_desde_staging.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/05_verificacion_shards.sql
docker exec -it citus_worker_1   psql -U postgres -d coorddb -f /sql/05b_validar_en_worker.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/05c_reconstruccion.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/06_transaccion_2pc.sql
docker exec -it citus_coordinator psql -U postgres -d coorddb -f /sql/07_consultas_distribuidas.sql
```

O todo de una vez, con pausas para capturar cada paso:

```
powershell -ExecutionPolicy Bypass -File .\guia_capturas.ps1
```

Para empezar de cero: `docker-compose down -v` (borra los volúmenes). Usuario `postgres`, contraseña `0000`,
base `coorddb`; desde pgAdmin, servidor `localhost`, puerto `5437`.
