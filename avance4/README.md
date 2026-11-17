# Avance 4 · Grupo 5 · Tripulación — Data Mart en MySQL 8.0 con ETL en Pentaho y dashboard en Metabase

Fuentes: staging PostgreSQL 16 (Unidades 1 y 2) + grafo Neo4j (Unidad 3). Destino: `dm_tripulacion` en **MySQL 8.0**
(motor opuesto a la Unidad 1, porque el Grupo 5 es impar). Esquema de **constelación**: 3 hechos y 6 dimensiones compartidas.

## Contenido

| Ruta | Qué es |
|---|---|
| `docker-compose.yaml` | PostgreSQL staging (5440), Neo4j (7474/7687), MySQL 8.0 Data Mart (3307), Metabase (3000) |
| `neo4j/00_indices_community.cypher` | Índices de unicidad para cargar el grafo de la U3 en Neo4j Community |
| `etl/exportar_neo4j.py` | Extracción NoSQL: Cypher → `etl/neo4j_csv/*.csv` |
| `etl/tr_01 … tr_05 *.ktr` | Transformaciones de Spoon (dimensiones, hechos de asignación, jornada y credenciales) |
| `etl/job_dm_tripulacion.kjb` | Job que ejecuta todo en orden y resuelve las claves sustitutas |
| `sql/01_dm_tripulacion_ddl.sql` | Esquema del Data Mart (se crea solo al levantar MySQL) |
| `sql/02_resolver_sk_y_cargar_hechos.sql` | SQL del paso final del job (claves naturales → SK) |
| `sql/03_vistas_metabase.sql` | Vistas de negocio para el dashboard |
| `sql/04_validacion_metricas.sql` | Consultas que validan las 6 métricas |
| `sql/05_trazabilidad.sql` | Recorrido de la asignación 66 desde el origen hasta el hecho |
| `sql/06_calidad_origen.sql` | Análisis de calidad de los datos de origen |
| `metabase/guia_dashboard.md` | SQL y configuración de las 9 tarjetas y los 2 filtros |
| `backup/` | Respaldo del Data Mart |

## Requisitos (Windows)
- Docker Desktop encendido.
- Pentaho Data Integration (Spoon) 9.x o 10.x y Java 11 o 17.
- **Driver de MySQL para Spoon**: descarga `mysql-connector-j-8.x.x.jar` y cópialo en `data-integration\lib` (cierra y abre Spoon).
- Python 3 con `pip install neo4j`.

## Atajo en Windows
En `pc/` hay cuatro scripts que hacen todo con doble clic: `0_descargar_herramientas` (Java 11, Pentaho 9.4 y el driver de MySQL), `1_levantar_entorno` (contenedores, grafo y exportación de Neo4j), `2_abrir_spoon` (abre el job) y `3_validar_y_respaldar` (métricas y respaldo). En `capturas_pc/` están los scripts que generan las salidas que aparecen como figuras en el informe.

## Paso a paso (PowerShell, dentro de la carpeta `avance4` del repositorio)

```powershell
# 1) Levantar todo (la primera vez descarga las imágenes; espera ~1 min a que PostgreSQL cargue el staging)
docker compose up -d

# 2) Cargar el grafo de la Unidad 3 en el Neo4j local (mismos scripts que se usaron en AuraDB)
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /scripts/00_indices_community.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /cypher/02_nodos.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 -f /cypher/03_relaciones.cypher
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH (n) RETURN count(n) AS nodos"
docker exec a4_neo4j cypher-shell -u neo4j -p tripulacion2026 "MATCH ()-[r]->() RETURN count(r) AS relaciones"
#    → 6694 nodos y 25583 relaciones

# 3) Extracción NoSQL → CSV
python etl\exportar_neo4j.py
#    → neo4j_tramos.csv: 5500 · neo4j_reemplazos.csv: 121 · neo4j_habilitaciones.csv: 1479

# 4) Spoon: Archivo → Abrir → etl\job_dm_tripulacion.kjb → Ejecutar (▶). Debe terminar en verde.

# 5) Validar las métricas
Get-Content sql\04_validacion_metricas.sql | docker exec -i a4_mysql_dm mysql -uroot -p0000 -t

# 6) Respaldo oficial del Data Mart
docker exec a4_mysql_dm sh -c "mysqldump -uroot -p0000 --databases dm_tripulacion > /tmp/dm_tripulacion.sql"
docker cp a4_mysql_dm:/tmp/dm_tripulacion.sql backup\dm_tripulacion.sql
```

7) Metabase en http://localhost:3000 → crear usuario → conectar MySQL (ver `metabase/guia_dashboard.md`).

## Valores esperados después del job
| Tabla | Filas |
|---|---|
| dim_tiempo / dim_region / dim_aeropuerto | 1827 / 3 / 42 |
| dim_tripulante / dim_vuelo / dim_credencial | 400 / 1100 / 14 |
| fact_asignacion / fact_jornada / fact_credencial | 5500 / 6529 / 2938 |

## Si algo falla
- **Spoon no conecta a MySQL**: falta el `.jar` del driver en `lib`, o el puerto 3307 está ocupado.
- **Paso CSV no encuentra el archivo**: corre primero el paso 3; los CSV deben quedar en `etl\neo4j_csv\`.
- **Plan B para la demo** (si el job no corre a tiempo): cargar el respaldo de referencia, que tiene exactamente los datos que produce la ETL:
  ```powershell
  docker cp backup\dm_tripulacion_referencia.sql a4_mysql_dm:/tmp/ref.sql
  docker exec a4_mysql_dm sh -c "mysql -uroot -p0000 < /tmp/ref.sql"
  ```
- Empezar de cero: `docker compose down -v`.
