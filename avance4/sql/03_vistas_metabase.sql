-- Vistas de negocio para Metabase (columnas con nombres que entiende un directivo)
USE dm_tripulacion;

CREATE OR REPLACE VIEW v_asignaciones AS
SELECT t.fecha AS fecha, t.anio_mes AS mes, CONCAT(t.anio, '-T', t.trimestre) AS trimestre,
       r.nombre_region AS region, ao.codigo_iata AS aeropuerto, ao.ciudad AS ciudad_origen, v.ruta, v.numero_vuelo,
       v.equipo, v.franja_salida, tr.nombre_completo AS tripulante, tr.cargo, tr.base_iata AS base, tr.base_region AS region_base,
       f.rol, f.horas_vuelo, f.retraso_minutos, f.vuelo_puntual, f.es_reemplazo, f.reemplazo_ultima_hora, f.aviso_horas,
       f.motivo_reemplazo, f.fuera_region_base, f.requirio_reposicionamiento, f.id_asignacion, f.sk_vuelo, f.sk_tripulante
  FROM fact_asignacion f
  JOIN dim_tiempo t      ON t.sk_tiempo = f.sk_tiempo
  JOIN dim_region r      ON r.sk_region = f.sk_region_origen
  JOIN dim_aeropuerto ao ON ao.sk_aeropuerto = f.sk_aeropuerto_origen
  JOIN dim_vuelo v       ON v.sk_vuelo = f.sk_vuelo
  JOIN dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante;

CREATE OR REPLACE VIEW v_jornadas AS
SELECT t.fecha AS fecha, t.anio_mes AS mes, r.nombre_region AS region, a.codigo_iata AS aeropuerto,
       tr.nombre_completo AS tripulante, tr.cargo, f.tipo_jornada, f.horas_servicio, f.descanso_previo_h,
       f.horas_servicio_7d, f.margen_60h_semana, f.cumple_jornada_13h, f.cumple_descanso_10h, f.cumple_60h_semana,
       f.cumple_jornada_maxima, f.id_jornada
  FROM fact_jornada f
  JOIN dim_tiempo t      ON t.sk_tiempo = f.sk_tiempo
  JOIN dim_region r      ON r.sk_region = f.sk_region_base
  JOIN dim_aeropuerto a  ON a.sk_aeropuerto = f.sk_aeropuerto_base
  JOIN dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante;

CREATE OR REPLACE VIEW v_credenciales AS
SELECT tv.fecha AS fecha_vencimiento, tv.anio_mes AS mes_vencimiento, r.nombre_region AS region, a.codigo_iata AS aeropuerto,
       tr.nombre_completo AS tripulante, tr.cargo, c.fuente, c.categoria, c.tipo AS credencial, c.equipo,
       f.estado, f.dias_para_vencer, f.proxima_a_vencer_90d, f.vencida, f.id_credencial
  FROM fact_credencial f
  JOIN dim_credencial c       ON c.sk_credencial = f.sk_credencial
  JOIN dim_region r           ON r.sk_region = f.sk_region_base
  JOIN dim_aeropuerto a       ON a.sk_aeropuerto = f.sk_aeropuerto_base
  JOIN dim_tripulante tr      ON tr.sk_tripulante = f.sk_tripulante
  LEFT JOIN dim_tiempo tv     ON tv.sk_tiempo = f.sk_tiempo_vencimiento;
