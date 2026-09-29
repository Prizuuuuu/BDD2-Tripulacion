-- =====================================================================
-- Avance 1 - Base de Datos 2 (Septiembre 2026)
-- Grupo 5 - Subsistema Tripulación - PostgreSQL 16
-- Índices propuestos: 3 B-tree (uno compuesto) + 2 Hash
-- =====================================================================

SET client_min_messages = warning;

CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE EXTENSION IF NOT EXISTS pageinspect;

DROP INDEX IF EXISTS idx_asignacion_tripulante, idx_asignacion_fecha, idx_asignacion_rol_fecha,
                     idx_asignacion_vuelo_hash, idx_vuelo_numero_hash;


-- B-tree: historial de vuelos de un tripulante y join asignacion -> tripulante
CREATE INDEX idx_asignacion_tripulante ON asignacion_tripulacion (id_tripulante);

-- B-tree: asignaciones en un rango de fechas (BETWEEN, ORDER BY)
CREATE INDEX idx_asignacion_fecha ON asignacion_tripulacion (fecha_asignacion);

-- B-tree compuesto: asignaciones de un rol en un rango de fechas (rol = ... AND fecha BETWEEN ...)
CREATE INDEX idx_asignacion_rol_fecha ON asignacion_tripulacion (rol, fecha_asignacion);

-- Hash: tripulación asignada a un vuelo (solo igualdad)
CREATE INDEX idx_asignacion_vuelo_hash ON asignacion_tripulacion USING HASH (id_vuelo);

-- Hash: historial de un número de vuelo, p. ej. 'AA1047' (solo igualdad)
CREATE INDEX idx_vuelo_numero_hash ON vuelo USING HASH (numero_vuelo);

ANALYZE asignacion_tripulacion;
ANALYZE vuelo;


SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_asignacion_tripulante', 'idx_asignacion_fecha', 'idx_asignacion_rol_fecha',
                    'idx_asignacion_vuelo_hash', 'idx_vuelo_numero_hash')
ORDER BY tablename, indexname;
