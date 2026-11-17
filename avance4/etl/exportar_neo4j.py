"""Extracción NoSQL del Avance 4: exporta del grafo de Tripulación (Neo4j, Unidad 3) los datos que
necesita el Data Mart y los deja en etl/neo4j_csv/ para que Pentaho Spoon los lea con CSV file input.

Uso (con el Neo4j del docker-compose levantado y el grafo cargado):
    pip install neo4j
    python exportar_neo4j.py
Variables opcionales: NEO4J_URI (bolt://localhost:7687), NEO4J_USER (neo4j), NEO4J_PASSWORD (tripulacion2026)
"""
import csv, os
from pathlib import Path
from neo4j import GraphDatabase

URI = os.environ.get('NEO4J_URI', 'bolt://localhost:7687')
USER = os.environ.get('NEO4J_USER', 'neo4j')
PWD = os.environ.get('NEO4J_PASSWORD', 'tripulacion2026')
OUT = Path(__file__).resolve().parent / 'neo4j_csv'

CONSULTAS = {
    # Cada tramo volado dentro de un pairing: equipo del vuelo y descanso desde el tramo anterior
    'neo4j_tramos.csv': ("""
        MATCH (t:Tripulante)-[:OPERA]->(p:Pairing)-[i:INCLUYE]->(v:Vuelo)
        OPTIONAL MATCH (:Vuelo)-[c:CONECTA_CON {id_pairing: p.id_pairing}]->(v)
        RETURN i.id_asignacion AS id_asignacion, t.id_tripulante AS id_tripulante, p.id_pairing AS id_pairing,
               i.orden AS orden, v.id_vuelo AS id_vuelo, v.equipo AS equipo,
               c.descanso_h AS descanso_previo_h, c.mismo_aeropuerto AS mismo_aeropuerto_previo
        ORDER BY id_asignacion""",
        ['id_asignacion', 'id_tripulante', 'id_pairing', 'orden', 'id_vuelo', 'equipo', 'descanso_previo_h', 'mismo_aeropuerto_previo']),
    # Cadenas de reemplazo: quién reemplazó a quién, con cuánto aviso y por qué
    'neo4j_reemplazos.csv': ("""
        MATCH (a:Tripulante)-[r:REEMPLAZADO_POR]->(b:Tripulante)
        RETURN r.id_asignacion AS id_asignacion, a.id_tripulante AS id_titular, b.id_tripulante AS id_sustituto,
               r.id_cadena AS id_cadena, r.eslabon AS eslabon, toString(r.fecha) AS fecha, r.id_vuelo AS id_vuelo,
               r.motivo AS motivo, r.aviso_horas AS aviso_horas
        ORDER BY id_asignacion""",
        ['id_asignacion', 'id_titular', 'id_sustituto', 'id_cadena', 'eslabon', 'fecha', 'id_vuelo', 'motivo', 'aviso_horas']),
    # Habilitaciones de equipo (type rating / familiarización), que no existen en el modelo relacional
    'neo4j_habilitaciones.csv': ("""
        MATCH (t:Tripulante)-[:TIENE_HABILITACION]->(h:Habilitacion)
        RETURN h.id_habilitacion AS id_habilitacion, t.id_tripulante AS id_tripulante, h.equipo AS equipo, h.tipo AS tipo,
               h.estado AS estado, h.fase AS fase, toString(h.fecha_emision) AS fecha_emision,
               toString(h.fecha_vencimiento) AS fecha_vencimiento, h.id_certificacion AS id_certificacion
        ORDER BY id_tripulante, id_habilitacion""",
        ['id_habilitacion', 'id_tripulante', 'equipo', 'tipo', 'estado', 'fase', 'fecha_emision', 'fecha_vencimiento', 'id_certificacion']),
}


def texto(v):
    if v is None:
        return ''
    if isinstance(v, bool):
        return 'true' if v else 'false'
    return v


def main():
    OUT.mkdir(exist_ok=True)
    with GraphDatabase.driver(URI, auth=(USER, PWD)) as driver:
        driver.verify_connectivity()
        for archivo, (cypher, columnas) in CONSULTAS.items():
            registros, _, _ = driver.execute_query(cypher)
            with open(OUT / archivo, 'w', newline='', encoding='utf-8') as f:
                w = csv.writer(f)
                w.writerow(columnas)
                for r in registros:
                    w.writerow([texto(r[c]) for c in columnas])
            print(f'{archivo}: {len(registros)} filas')


if __name__ == '__main__':
    main()
