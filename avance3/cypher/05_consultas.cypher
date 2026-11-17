// =====================================================================
// 05. Consultas Cypher
// =====================================================================

// ---------------------------------------------------------------------
// CONSULTAS BÁSICAS
// ---------------------------------------------------------------------

// B1. Patrón directo: tripulación que operó el vuelo 500 y en qué pairing lo voló cada uno
MATCH (t:Tripulante)-[o:OPERA]->(p:Pairing)-[i:INCLUYE]->(v:Vuelo {id_vuelo: 500})
RETURN v.numero_vuelo AS vuelo, v.origen + ' → ' + v.destino AS ruta, t.numero_empleado AS empleado,
       o.rol AS rol, p.id_pairing AS pairing, i.orden AS tramo_del_pairing, i.id_asignacion AS id_asignacion
ORDER BY rol;

// B2. Filtrado por propiedades: habilitaciones de B787-8 que todavía están en entrenamiento
MATCH (t:Tripulante)-[:TIENE_HABILITACION]->(h:Habilitacion)
WHERE h.equipo = 'B787-8' AND h.estado = 'EN_ENTRENAMIENTO'
RETURN t.numero_empleado AS empleado, t.cargo AS cargo, t.base AS base, h.fase AS fase, h.fecha_emision AS inicio
ORDER BY inicio;

// B3. Búsqueda por etiqueta: pairings de mayo con dos o más posicionamientos (tramos sin continuidad de aeropuerto)
MATCH (p:Pairing)
WHERE p.mes = '2026-05' AND p.posicionamientos >= 2
RETURN p.id_pairing AS pairing, p.base AS base, p.num_tramos AS tramos, p.posicionamientos AS posicionamientos,
       p.horas_vuelo AS horas
ORDER BY posicionamientos DESC, horas DESC
LIMIT 10;

// B4. Valor dentro de una lista: sesiones de simulador que practicaron falla de motor en V1
MATCH (alumno:Tripulante)-[:RECIBE]->(i:Instruccion)
WHERE i.modalidad = 'SIMULADOR' AND 'FALLA_MOTOR_V1' IN i.maniobras
RETURN i.id_instruccion AS instruccion, alumno.numero_empleado AS alumno, i.equipo AS equipo,
       i.horas_simulador AS horas, i.fecha AS fecha
ORDER BY fecha DESC
LIMIT 10;

// B5. Filtro sobre relaciones: reemplazos provocados por un certificado médico vencido
MATCH (titular:Tripulante)-[r:REEMPLAZADO_POR {motivo: 'CERTIFICADO_MEDICO_VENCIDO'}]->(sust:Tripulante)
RETURN r.fecha AS fecha, titular.numero_empleado AS titular, sust.numero_empleado AS sustituto,
       titular.cargo AS cargo, r.id_vuelo AS id_vuelo, r.aviso_horas AS aviso_h
ORDER BY fecha;

// ---------------------------------------------------------------------
// CONSULTAS COMPLEJAS
// ---------------------------------------------------------------------

// C1. shortestPath (problema real): cadena de tripulantes que conecta a dos personas que nunca han volado juntas
//     (el piloto 5, base DCA, región ESTE, y el jefe de cabina 52, base ORD, región CENTRAL)
MATCH (a:Tripulante {id_tripulante: 5}), (b:Tripulante {id_tripulante: 52})
WHERE NOT EXISTS { MATCH (a)-[:VOLO_CON]-(b) }
MATCH camino = shortestPath((a)-[:VOLO_CON*..6]-(b))
RETURN [t IN nodes(camino) | t.numero_empleado + ' (' + t.cargo + ', ' + t.base + ')'] AS cadena,
       [r IN relationships(camino) | r.ultimo_vuelo] AS vuelo_que_los_une,
       length(camino) AS saltos;

// C2. Caminos de longitud variable: cadenas de reemplazo completas (desde el titular original hasta el último sustituto)
MATCH cadena = (inicio:Tripulante)-[:REEMPLAZADO_POR*1..5]->(fin:Tripulante)
WHERE all(r IN relationships(cadena) WHERE r.id_cadena = relationships(cadena)[0].id_cadena)
  AND NOT EXISTS { MATCH ()-[x:REEMPLAZADO_POR]->(inicio) WHERE x.id_cadena = relationships(cadena)[0].id_cadena }
  AND NOT EXISTS { MATCH (fin)-[x:REEMPLAZADO_POR]->() WHERE x.id_cadena = relationships(cadena)[0].id_cadena }
RETURN relationships(cadena)[0].id_cadena AS cadena_id, relationships(cadena)[0].fecha AS fecha,
       relationships(cadena)[0].motivo AS motivo_inicial,
       [t IN nodes(cadena) | t.numero_empleado] AS secuencia, length(cadena) AS eslabones
ORDER BY eslabones DESC, fecha
LIMIT 10;

// C3. Relaciones reversas + caminos cuantificados: linaje de instrucción del piloto 85
//     (quién lo instruyó, quién instruyó a su instructor, ...)
MATCH linaje = (alumno:Tripulante {id_tripulante: 85})
      ((x:Tripulante)-[:RECIBE]->(:Instruccion)<-[:IMPARTE]-(y:Tripulante)){1,3}
WITH linaje ORDER BY length(linaje) DESC LIMIT 1
RETURN [n IN nodes(linaje) WHERE n:Tripulante | n.numero_empleado + ' (' + n.cargo + ')'] AS linaje_instruccion,
       [n IN nodes(linaje) WHERE n:Instruccion | n.curso + ' ' + toString(n.fecha)] AS cursos;

// C4. COUNT + COLLECT: los tripulantes con más compañeros distintos por región y con quién más han volado
MATCH (t:Tripulante)-[v:VOLO_CON]-(c:Tripulante)
WITH t, count(c) AS companeros, sum(v.vuelos_juntos) AS vuelos_compartidos,
     collect({empleado: c.numero_empleado, veces: v.vuelos_juntos}) AS lista
WITH t, companeros, vuelos_compartidos,
     [x IN lista WHERE x.veces = reduce(m = 0, y IN lista | CASE WHEN y.veces > m THEN y.veces ELSE m END) | x.empleado] AS mas_frecuentes
ORDER BY companeros DESC
WITH t.region AS region, collect({empleado: t.numero_empleado, cargo: t.cargo, companeros: companeros,
                                 mas_frecuentes: mas_frecuentes[0..3]})[0..3] AS top3
RETURN region, top3
ORDER BY region;

// C5. Problema real: candidatos para reemplazar al piloto del vuelo 500
//     (mismo cargo, habilitación vigente en el equipo, sin otro vuelo ese día, y que ya haya volado con el copiloto)
MATCH (titular:Tripulante {cargo: 'PILOTO'})-[:OPERA]->(:Pairing)-[:INCLUYE]->(v:Vuelo {id_vuelo: 500})
MATCH (cop:Tripulante {cargo: 'COPILOTO'})-[:OPERA]->(:Pairing)-[:INCLUYE]->(v)
MATCH (cand:Tripulante {cargo: 'PILOTO', estado: 'ACTIVO'})-[:TIENE_HABILITACION]->(h:Habilitacion {equipo: v.equipo, estado: 'VIGENTE'})
WHERE cand <> titular
  AND h.fecha_emision <= date(v.salida) AND h.fecha_vencimiento >= date(v.llegada)
  AND NOT EXISTS {
    MATCH (cand)-[:OPERA]->(:Pairing)-[:INCLUYE]->(otro:Vuelo)
    WHERE date(otro.salida) = date(v.salida)
  }
OPTIONAL MATCH (cand)-[conoce:VOLO_CON]-(cop)
RETURN v.numero_vuelo AS vuelo, v.equipo AS equipo, titular.numero_empleado AS titular,
       cand.numero_empleado AS candidato, cand.base AS base_candidato,
       coalesce(conoce.vuelos_juntos, 0) AS vuelos_con_el_copiloto,
       cand.base = v.origen AS esta_en_el_aeropuerto
ORDER BY vuelos_con_el_copiloto DESC, esta_en_el_aeropuerto DESC
LIMIT 5;

// ---------------------------------------------------------------------
// CONSULTAS ADICIONALES DE OPERACIÓN
// ---------------------------------------------------------------------

// C6. Carga de cada base: pairings del semestre, horas, promedio por pairing y tramos con posicionamiento
MATCH (t:Tripulante)-[:OPERA]->(p:Pairing)
RETURN p.base AS base, count(p) AS pairings, count(DISTINCT t) AS tripulantes,
       round(sum(p.horas_vuelo), 1) AS horas, round(avg(p.horas_vuelo), 1) AS horas_por_pairing,
       sum(coalesce(p.posicionamientos, 0)) AS posicionamientos
ORDER BY horas DESC;

// C7. Habilitaciones que vencen en los 90 días siguientes al cierre del semestre, en equipos que el tripulante vuela
MATCH (t:Tripulante)-[:TIENE_HABILITACION]->(h:Habilitacion {estado: 'VIGENTE', tipo: 'TYPE_RATING'})
WHERE h.fecha_vencimiento > date('2026-06-30') AND h.fecha_vencimiento <= date('2026-06-30') + duration({days: 90})
OPTIONAL MATCH (t)-[:RECIBE]->(i:Instruccion)-[:OTORGA]->(h)
RETURN t.numero_empleado AS empleado, t.cargo AS cargo, h.equipo AS equipo, h.fecha_vencimiento AS vence,
       i.id_certificacion AS certificacion_relacional
ORDER BY vence;
