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
SELECT tr.nombre_completo, tr.cargo, tr.base_iata, SUM(f.horas_vuelo) AS horas_acumuladas
  FROM fact_asignacion f JOIN dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante
 GROUP BY tr.nombre_completo, tr.cargo, tr.base_iata
 ORDER BY horas_acumuladas DESC LIMIT 10;

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

-- M4. Cumplimiento de jornada máxima (jornada <= 13 h, descanso >= 10 h, <= 60 h en 7 días)
SELECT ROUND(100.0 * AVG(cumple_jornada_maxima), 2) AS cumplimiento_pct,
       COUNT(*) - SUM(cumple_jornada_maxima) AS jornadas_que_incumplen,
       COUNT(*) - SUM(cumple_jornada_13h) AS exceden_13h,
       COUNT(*) - SUM(cumple_descanso_10h) AS descanso_menor_10h,
       COUNT(*) - SUM(cumple_60h_semana) AS exceden_60h_7d,
       COUNT(*) AS jornadas
  FROM fact_jornada;

-- M5. Certificaciones y habilitaciones próximas a vencer (90 días desde el corte 30/06/2026)
SELECT c.fuente, c.tipo, SUM(f.proxima_a_vencer_90d) AS proximas_a_vencer
  FROM fact_credencial f JOIN dim_credencial c ON c.sk_credencial = f.sk_credencial
 GROUP BY c.fuente, c.tipo HAVING SUM(f.proxima_a_vencer_90d) > 0 ORDER BY proximas_a_vencer DESC;
SELECT SUM(proxima_a_vencer_90d) AS total_proximas_a_vencer,
       COUNT(DISTINCT CASE WHEN proxima_a_vencer_90d = 1 THEN sk_tripulante END) AS tripulantes_afectados
  FROM fact_credencial;

-- M6. Distribución de carga por base operativa
SELECT tr.base_iata, tr.base_region, COUNT(DISTINCT f.sk_tripulante) AS tripulantes, SUM(f.horas_vuelo) AS horas,
       ROUND(SUM(f.horas_vuelo) / COUNT(DISTINCT f.sk_tripulante), 1) AS horas_por_tripulante,
       ROUND(100.0 * SUM(f.horas_vuelo) / (SELECT SUM(horas_vuelo) FROM fact_asignacion), 1) AS pct_de_las_horas
  FROM fact_asignacion f JOIN dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante
 GROUP BY tr.base_iata, tr.base_region ORDER BY horas DESC;

-- Hallazgo: ¿qué parte de los puestos de cada región los cubre tripulación basada en esa región?
SELECT r.nombre_region AS region_de_salida, COUNT(*) AS puestos,
       SUM(1 - f.fuera_region_base) AS cubiertos_por_tripulacion_local,
       ROUND(100.0 * AVG(1 - f.fuera_region_base), 1) AS cobertura_local_pct
  FROM fact_asignacion f JOIN dim_region r ON r.sk_region = f.sk_region_origen
 GROUP BY r.nombre_region ORDER BY cobertura_local_pct;
