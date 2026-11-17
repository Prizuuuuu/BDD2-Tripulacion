-- Trazabilidad: recorrido de la asignación 66 desde el origen operativo hasta la tabla de hechos
-- (1) Origen relacional — PostgreSQL staging (puerto 5440, base tripulacion)
SELECT a.id_asignacion, a.id_tripulante, a.id_vuelo, a.rol, a.horas_vuelo, v.numero_vuelo, v.fecha_salida_real, v.retraso_minutos
  FROM staging.asignacion_tripulacion a JOIN staging.vuelo v ON v.id_vuelo = a.id_vuelo WHERE a.id_asignacion = 66;
-- (2) Origen NoSQL — Neo4j (Browser en http://localhost:7474)
-- MATCH (t:Tripulante)-[:OPERA]->(p:Pairing)-[i:INCLUYE {id_asignacion: 66}]->(v:Vuelo) RETURN t, p, i, v;
-- MATCH (a)-[r:REEMPLAZADO_POR {id_asignacion: 66}]->(b) RETURN a.id_tripulante, b.id_tripulante, r.motivo, r.aviso_horas;
-- (3) Tabla de paso — MySQL (puerto 3307)
SELECT * FROM dm_tripulacion.stg_asignacion WHERE id_asignacion = 66;
-- (4) Hecho final con sus claves sustitutas y su significado
SELECT f.id_asignacion, f.sk_tiempo, t.fecha, f.sk_tripulante, tr.id_tripulante, tr.nombre_completo, f.sk_vuelo, v.id_vuelo, v.numero_vuelo,
       v.ruta, v.equipo, f.horas_vuelo, f.retraso_minutos, f.id_pairing, f.es_reemplazo, f.reemplazo_ultima_hora, f.aviso_horas, f.motivo_reemplazo
  FROM dm_tripulacion.fact_asignacion f
  JOIN dm_tripulacion.dim_tiempo t ON t.sk_tiempo = f.sk_tiempo
  JOIN dm_tripulacion.dim_tripulante tr ON tr.sk_tripulante = f.sk_tripulante
  JOIN dm_tripulacion.dim_vuelo v ON v.sk_vuelo = f.sk_vuelo
 WHERE f.id_asignacion = 66;
-- (5) Conciliación de conteos origen vs Data Mart
SELECT (SELECT COUNT(*) FROM dm_tripulacion.fact_asignacion) AS fact_asignacion,     -- debe ser 5500 (= staging.asignacion_tripulacion)
       (SELECT COUNT(*) FROM dm_tripulacion.fact_jornada) AS fact_jornada,           -- debe ser 6529 (= staging.jornada_laboral)
       (SELECT COUNT(*) FROM dm_tripulacion.fact_credencial) AS fact_credencial,     -- debe ser 2938 (= 1459 certificaciones + 1479 habilitaciones)
       (SELECT SUM(horas_vuelo) FROM dm_tripulacion.fact_asignacion) AS horas_dm;    -- debe ser 16544.25 (= SUM en staging)
