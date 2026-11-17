USE dm_tripulacion;
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
-- M6. Distribución de carga por base operativa
SELECT tr.base_iata, tr.base_region, COUNT(DISTINCT f.sk_tripulante) AS tripulantes, SUM(f.horas_vuelo) AS horas,
       ROUND(SUM(f.horas_vuelo) / COUNT(DISTINCT f.sk_tripulante), 1) AS horas_por_tripulante,
       ROUND(100.0 * SUM(f.horas_vuelo) / (SELECT SUM(horas_vuelo) FROM fact_asignacion), 1) AS pct_de_las_horas
  FROM fact_asignacion f JOIN dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante
 GROUP BY tr.base_iata, tr.base_region ORDER BY horas DESC;

