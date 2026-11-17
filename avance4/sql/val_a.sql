-- =====================================================================
-- Validación numérica de las 6 métricas sobre el Data Mart (MySQL 8.0)
-- (SQL estándar: también corre igual en PostgreSQL)
-- =====================================================================
USE dm_tripulacion;

-- M1. Horas de vuelo acumuladas por tripulante (resumen y top 10)
SELECT COUNT(DISTINCT sk_tripulante) AS tripulantes_que_volaron,
       SUM(horas_vuelo) AS horas_totales,
       ROUND(SUM(horas_vuelo) / COUNT(DISTINCT sk_tripulante), 2) AS horas_promedio_por_tripulante
  FROM fact_asignacion;
-- M2. Tripulantes asignados por vuelo (promedio y composición por rol)
SELECT ROUND(1.0 * COUNT(*) / COUNT(DISTINCT sk_vuelo), 2) AS tripulantes_por_vuelo, COUNT(DISTINCT sk_vuelo) AS vuelos
  FROM fact_asignacion;
SELECT rol, ROUND(1.0 * COUNT(*) / COUNT(DISTINCT sk_vuelo), 2) AS por_vuelo FROM fact_asignacion GROUP BY rol ORDER BY rol;

-- M3. Tasa de reemplazos de última hora (aviso <= 6 h), dato que proviene de Neo4j
SELECT SUM(es_reemplazo) AS reemplazos, SUM(reemplazo_ultima_hora) AS reemplazos_ultima_hora,
       ROUND(100.0 * SUM(reemplazo_ultima_hora) / COUNT(*), 2) AS tasa_ultima_hora_pct
  FROM fact_asignacion;
SELECT r.nombre_region, SUM(f.reemplazo_ultima_hora) AS ultima_hora, COUNT(*) AS asignaciones,
       ROUND(100.0 * SUM(f.reemplazo_ultima_hora) / COUNT(*), 2) AS tasa_pct
  FROM fact_asignacion f JOIN dim_region r ON r.sk_region = f.sk_region_origen
 GROUP BY r.nombre_region ORDER BY r.nombre_region;

