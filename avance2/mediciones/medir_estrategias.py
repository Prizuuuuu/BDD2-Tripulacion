# Mide cada estrategia de consulta distribuida: 1 ejecución de calentamiento + 15 medidas,
# mediana del Execution Time de EXPLAIN ANALYZE. Requiere el clúster levantado (docker-compose up -d)
# y los scripts 01 a 04 ejecutados.
#   python mediciones/medir_estrategias.py
import json, statistics, subprocess

REP = "SET citus.enable_repartition_joins = on; SET citus.multi_shard_modify_mode TO 'sequential';"
Q1 = """SELECT r.nombre_region, a.codigo_iata AS base, count(*) AS asignaciones, sum(h.horas_vuelo) AS horas_vuelo
FROM asignacion_horas h JOIN tripulante t ON t.id_tripulante = h.id_tripulante {extra}
JOIN hub hb ON hb.id_hub = t.id_hub_base JOIN aeropuerto a ON a.id_aeropuerto = hb.id_aeropuerto
JOIN region r ON r.id_region = t.id_region {where} GROUP BY r.nombre_region, a.codigo_iata ORDER BY 1, 2"""
Q1S = """SELECT r.nombre_region, a.codigo_iata AS base, count(*), sum(x.horas_vuelo)
FROM staging.asignacion_tripulacion x JOIN staging.tripulante t ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb ON hb.id_hub = t.id_hub_base JOIN staging.aeropuerto a ON a.id_aeropuerto = hb.id_aeropuerto
JOIN staging.region r ON r.id_region = a.id_region GROUP BY 1, 2 ORDER BY 1, 2"""
Q2 = """SELECT rb.nombre_region, ro.nombre_region, count(*), sum(h.horas_vuelo)
FROM asignacion_horas h JOIN asignacion_operacion o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region JOIN region ro ON ro.id_region = o.id_region GROUP BY 1, 2 ORDER BY 1, 2"""
Q2G = """WITH h AS MATERIALIZED (SELECT id_asignacion, id_region, horas_vuelo FROM asignacion_horas),
o AS MATERIALIZED (SELECT id_asignacion, id_region FROM asignacion_operacion)
SELECT rb.nombre_region, ro.nombre_region, count(*), sum(h.horas_vuelo) FROM h JOIN o ON o.id_asignacion = h.id_asignacion
JOIN region rb ON rb.id_region = h.id_region JOIN region ro ON ro.id_region = o.id_region GROUP BY 1, 2 ORDER BY 1, 2"""
Q2S = """SELECT rb.nombre_region, ro.nombre_region, count(*), sum(x.horas_vuelo)
FROM staging.asignacion_tripulacion x JOIN staging.tripulante t ON t.id_tripulante = x.id_tripulante
JOIN staging.hub hb ON hb.id_hub = t.id_hub_base JOIN staging.aeropuerto ab ON ab.id_aeropuerto = hb.id_aeropuerto
JOIN staging.vuelo v ON v.id_vuelo = x.id_vuelo JOIN staging.aeropuerto av ON av.id_aeropuerto = v.id_aeropuerto_origen
JOIN staging.region rb ON rb.id_region = ab.id_region JOIN staging.region ro ON ro.id_region = av.id_region GROUP BY 1, 2 ORDER BY 1, 2"""
CASOS = [
    ('1A co-located + referencia', '', Q1.format(extra='AND t.id_region = h.id_region', where='')),
    ('1B repartition join', REP, Q1.format(extra='', where='')),
    ('1C router (solo ESTE)', '', Q1.format(extra='AND t.id_region = h.id_region', where='WHERE h.id_region = 1')),
    ('1D staging central', '', Q1S),
    ('2A repartition join', REP, Q2),
    ('2B gather en coordinador', '', Q2G),
    ('2C staging central', '', Q2S),
]
N = 15

for nombre, pre, q in CASOS:
    script = pre + '\n' + '\n'.join([f"EXPLAIN (ANALYZE, FORMAT JSON) {q};"] * (N + 1))
    salida = subprocess.run(['docker', 'exec', '-i', 'citus_coordinator', 'psql', '-U', 'postgres', '-d', 'coorddb', '-tA'],
                            input=script, capture_output=True, text=True, encoding='utf-8').stdout
    dec, i, planes = json.JSONDecoder(), 0, []
    s = salida.strip()
    while i < len(s):
        while i < len(s) and s[i] in ' \n\r\tSET':
            i += 1
        if i >= len(s):
            break
        plan, i = dec.raw_decode(s, i)
        planes.append(plan[0])
    tiempos = [p['Execution Time'] for p in planes[1:]]
    print(f'{nombre:28s} mediana {statistics.median(tiempos):8.2f} ms   min {min(tiempos):8.2f}   max {max(tiempos):8.2f}   n={len(tiempos)}')
