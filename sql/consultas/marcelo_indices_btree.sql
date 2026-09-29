-- ============================================================
-- PROYECTO BASE DE DATOS - ANÁLISIS DE ÍNDICES B-TREE
-- Integrante: Marcelo
-- Base de Datos: tripulacion | Tabla: asignacion_tripulacion
-- ============================================================

-- Habilitar extensiones requeridas para métricas y metadatos
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE EXTENSION IF NOT EXISTS pageinspect;


-- ============================================================
-- 1. ÍNDICE 1: fecha_asignacion
-- ============================================================

-- D1.1: Consulta SIN índice en fecha_asignacion (Seq Scan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM asignacion_tripulacion
WHERE fecha_asignacion BETWEEN '2026-03-01' AND '2026-03-07';

-- D1.2: Creación del primer índice B-tree y actualización de estadísticas
CREATE INDEX idx_asig_fecha ON asignacion_tripulacion (fecha_asignacion);
ANALYZE asignacion_tripulacion;

-- D1.3: Consulta CON índice en fecha_asignacion (Index Scan / Bitmap Index Scan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM asignacion_tripulacion
WHERE fecha_asignacion BETWEEN '2026-03-01' AND '2026-03-07';

-- D1.4: Métricas internas del árbol B-tree
SELECT * FROM pgstatindex('idx_asig_fecha');

-- Consultas complementarias de metadatos y tamaño
SELECT * FROM bt_metap('idx_asig_fecha');
SELECT pg_size_pretty(pg_relation_size('idx_asig_fecha')) AS tamano_indice_1;


-- ============================================================
-- 2. ÍNDICE 2: id_tripulante
-- ============================================================

-- D2.1: Consulta SIN índice en id_tripulante (Seq Scan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM asignacion_tripulacion
WHERE id_tripulante = 285;

-- D2.2: Creación del segundo índice B-tree y actualización de estadísticas
CREATE INDEX idx_asig_empleado ON asignacion_tripulacion (id_tripulante);
ANALYZE asignacion_tripulacion;

-- D2.3: Consulta CON índice en id_tripulante (Index Scan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM asignacion_tripulacion
WHERE id_tripulante = 285;

-- D2.4: Métricas internas del segundo árbol B-tree
SELECT * FROM pgstatindex('idx_asig_empleado');

-- Consultas complementarias de metadatos y tamaño
SELECT * FROM bt_metap('idx_asig_empleado');
SELECT pg_size_pretty(pg_relation_size('idx_asig_empleado')) AS tamano_indice_2;