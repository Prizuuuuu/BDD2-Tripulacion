-- =====================================================================
-- Paso final del job (entrada SQL "Resolver SK y cargar hechos") — MySQL 8.0
-- Convierte las claves naturales de las tablas stg_ en claves sustitutas
-- =====================================================================
USE dm_tripulacion;

-- 1) Dimensiones que dependen de otras dimensiones
UPDATE dim_aeropuerto a JOIN dim_region r ON r.id_region = a.id_region
   SET a.sk_region = r.sk_region, a.region = r.nombre_region;
UPDATE dim_tripulante t JOIN dim_aeropuerto a ON a.codigo_iata = t.base_iata
   SET t.sk_aeropuerto_base = a.sk_aeropuerto, t.sk_region_base = a.sk_region, t.base_region = a.region;

-- 2) dim_credencial: catálogo de tipos de las dos fuentes
INSERT INTO dim_credencial (fuente, categoria, tipo, equipo)
SELECT DISTINCT s.fuente, s.categoria, s.tipo, s.equipo FROM stg_credencial s
 WHERE NOT EXISTS (SELECT 1 FROM dim_credencial d WHERE d.fuente = s.fuente AND d.tipo = s.tipo AND d.equipo <=> s.equipo);

-- 3) fact_asignacion (relacional + Neo4j)
INSERT INTO fact_asignacion
SELECT CAST(DATE_FORMAT(s.fecha_salida, '%Y%m%d') AS UNSIGNED), t.sk_tripulante, v.sk_vuelo, ao.sk_aeropuerto, ad.sk_aeropuerto, ao.sk_region,
       s.id_asignacion, s.id_pairing, s.orden_en_pairing, s.rol, s.horas_vuelo, s.retraso_minutos,
       (s.retraso_minutos <= 15),
       s.descanso_previo_h,
       CASE s.mismo_aeropuerto_previo WHEN 'true' THEN 0 WHEN 'false' THEN 1 ELSE NULL END,
       (ao.sk_region <> t.sk_region_base),
       (s.aviso_horas IS NOT NULL),
       COALESCE(s.aviso_horas <= 6, 0),
       s.aviso_horas, s.motivo_reemplazo
  FROM stg_asignacion s
  JOIN dim_tripulante t  ON t.id_tripulante = s.id_tripulante
  JOIN dim_vuelo v       ON v.id_vuelo = s.id_vuelo
  JOIN dim_aeropuerto ao ON ao.codigo_iata = s.origen
  JOIN dim_aeropuerto ad ON ad.codigo_iata = s.destino;

-- 4) fact_jornada
INSERT INTO fact_jornada
SELECT CAST(DATE_FORMAT(s.fecha_jornada, '%Y%m%d') AS UNSIGNED), t.sk_tripulante, t.sk_aeropuerto_base, t.sk_region_base,
       s.id_jornada, s.tipo_jornada, s.horas_servicio, s.tramos_volados, s.horas_vuelo_dia, s.descanso_previo_h,
       s.horas_servicio_7d, s.margen_60h_semana,
       (s.horas_servicio <= 13),
       COALESCE(s.descanso_previo_h >= 10, 1),
       (s.horas_servicio_7d <= 60),
       (s.horas_servicio <= 13 AND COALESCE(s.descanso_previo_h >= 10, 1) AND s.horas_servicio_7d <= 60)
  FROM stg_jornada s
  JOIN dim_tripulante t ON t.id_tripulante = s.id_tripulante;

-- 5) fact_credencial (foto al 30/06/2026, último día con datos operativos)
INSERT INTO fact_credencial
SELECT 20260630,
       CAST(DATE_FORMAT(s.fecha_vencimiento, '%Y%m%d') AS UNSIGNED),
       t.sk_tripulante, d.sk_credencial, t.sk_aeropuerto_base, t.sk_region_base,
       s.id_credencial, s.estado,
       DATEDIFF(s.fecha_vencimiento, '2026-06-30'),
       COALESCE(s.estado = 'Vigente' AND s.fecha_vencimiento BETWEEN '2026-06-30' AND DATE_ADD('2026-06-30', INTERVAL 90 DAY), 0),
       COALESCE(s.fecha_vencimiento < '2026-06-30', 0)
  FROM stg_credencial s
  JOIN dim_tripulante t ON t.id_tripulante = s.id_tripulante
  JOIN dim_credencial d ON d.fuente = s.fuente AND d.tipo = s.tipo AND d.equipo <=> s.equipo;

-- 6) Conteo final
SELECT 'fact_asignacion' AS tabla, COUNT(*) AS filas FROM fact_asignacion
UNION ALL SELECT 'fact_jornada', COUNT(*) FROM fact_jornada
UNION ALL SELECT 'fact_credencial', COUNT(*) FROM fact_credencial;
