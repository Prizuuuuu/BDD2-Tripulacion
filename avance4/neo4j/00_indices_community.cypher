// Índices de unicidad para cargar el grafo en Neo4j Community (local).
// Reemplazan a 01_restricciones.cypher, que usa restricciones solo disponibles en AuraDB / Enterprise.
CREATE CONSTRAINT trip_id IF NOT EXISTS FOR (t:Tripulante) REQUIRE t.id_tripulante IS UNIQUE;
CREATE CONSTRAINT vuelo_id IF NOT EXISTS FOR (v:Vuelo) REQUIRE v.id_vuelo IS UNIQUE;
CREATE CONSTRAINT pairing_id IF NOT EXISTS FOR (p:Pairing) REQUIRE p.id_pairing IS UNIQUE;
CREATE CONSTRAINT hab_id IF NOT EXISTS FOR (h:Habilitacion) REQUIRE h.id_habilitacion IS UNIQUE;
CREATE CONSTRAINT inst_id IF NOT EXISTS FOR (i:Instruccion) REQUIRE i.id_instruccion IS UNIQUE;
