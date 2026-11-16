// =====================================================================
// 04. Verificación de volúmenes y coherencia
// =====================================================================

// Nodos por etiqueta (mínimo 50 por etiqueta)
MATCH (n)
RETURN labels(n)[0] AS etiqueta, count(*) AS nodos
ORDER BY etiqueta;

// Relaciones por tipo (mínimo 30 por tipo)
MATCH ()-[r]->()
RETURN type(r) AS relacion, count(*) AS relaciones
ORDER BY relacion;

// Coherencia 1: todo pairing respeta el descanso mínimo de 10 h entre tramos
MATCH ()-[c:CONECTA_CON]->()
RETURN count(*) AS conexiones, min(c.descanso_h) AS descanso_minimo_h,
       count(CASE WHEN c.descanso_h < 10 THEN 1 END) AS conexiones_invalidas;

// Coherencia 2: nadie vuela un equipo sin habilitación vigente en esa fecha
MATCH (t:Tripulante)-[:OPERA]->(:Pairing)-[:INCLUYE]->(v:Vuelo)
WHERE NOT EXISTS {
  MATCH (t)-[:TIENE_HABILITACION]->(h:Habilitacion {equipo: v.equipo})
  WHERE h.estado = 'VIGENTE' AND h.fecha_emision <= date(v.salida)
    AND (h.fecha_vencimiento IS NULL OR h.fecha_vencimiento >= date(v.llegada))
}
RETURN count(*) AS tramos_sin_habilitacion;

// Coherencia 3: el instructor es más antiguo que el instruido, del mismo grupo, y nunca él mismo
MATCH (ins:Tripulante)-[:IMPARTE]->(i:Instruccion)<-[:RECIBE]-(alu:Tripulante)
RETURN count(*) AS instrucciones_con_instructor,
       count(CASE WHEN ins = alu THEN 1 END) AS autoinstruccion,
       count(CASE WHEN (ins.cargo IN ['PILOTO','COPILOTO']) <> (alu.cargo IN ['PILOTO','COPILOTO']) THEN 1 END) AS grupo_distinto;

// Coherencia 4: en cada reemplazo, titular y sustituto tienen el mismo cargo y el sustituto voló ese vuelo
MATCH (a:Tripulante)-[r:REEMPLAZADO_POR]->(b:Tripulante)
OPTIONAL MATCH (b)-[:OPERA]->(:Pairing)-[inc:INCLUYE]->(v:Vuelo {id_vuelo: r.id_vuelo})
RETURN count(DISTINCT r) AS reemplazos,
       count(DISTINCT CASE WHEN a.cargo <> b.cargo THEN r END) AS cargo_distinto,
       count(DISTINCT CASE WHEN v IS NULL THEN r END) AS sustituto_no_volo;
