# Genera los scripts Cypher de carga del grafo de Tripulación a partir del staging relacional (Unidad 1).
# Lee la base con psql y escribe ../cypher/02_nodos.cypher y ../cypher/03_relaciones.cypher.
#   python generar_grafo.py [puerto] [base]      (psql en el PATH, o su ruta en la variable PSQL)
import csv, io, json, os, random, subprocess, sys
from collections import defaultdict
from datetime import datetime, timedelta, date
from pathlib import Path

PSQL = os.environ.get('PSQL', 'psql')
PUERTO = sys.argv[1] if len(sys.argv) > 1 else '5432'
BASE = sys.argv[2] if len(sys.argv) > 2 else 'tripulacion'
OUT = Path(__file__).resolve().parent.parent / 'cypher'
random.seed(2026)


def consulta(sql):
    r = subprocess.run([PSQL, '-p', PUERTO, '-U', 'postgres', '-d', BASE, '-c',
                        f"\\copy ({sql}) TO STDOUT WITH CSV HEADER"],
                       capture_output=True, text=True, encoding='utf-8', check=True)
    return list(csv.DictReader(io.StringIO(r.stdout)))


def ts(s):
    return datetime.fromisoformat(s)


def d(s):
    return date.fromisoformat(s)


# ---------------------------------------------------------------------
# Datos del staging
# ---------------------------------------------------------------------
trip = consulta("""SELECT t.id_tripulante, t.numero_empleado, t.cargo, t.estado, t.fecha_ingreso,
                          a.codigo_iata AS base, r.nombre_region AS region
                   FROM public.tripulante t JOIN public.hub h ON h.id_hub = t.id_hub_base
                   JOIN public.aeropuerto a ON a.id_aeropuerto = h.id_aeropuerto
                   JOIN public.region r ON r.id_region = a.id_region""")
vuel = consulta("""SELECT v.id_vuelo, v.numero_vuelo, v.fecha_salida_real AS salida, v.fecha_llegada_real AS llegada,
                          o.codigo_iata AS origen, de.codigo_iata AS destino, ro.nombre_region AS region_origen,
                          v.retraso_minutos, v.estado
                   FROM public.vuelo v JOIN public.aeropuerto o ON o.id_aeropuerto = v.id_aeropuerto_origen
                   JOIN public.aeropuerto de ON de.id_aeropuerto = v.id_aeropuerto_destino
                   JOIN public.region ro ON ro.id_region = o.id_region""")
asig = consulta("""SELECT id_asignacion, id_tripulante, id_vuelo, rol, horas_vuelo, fecha_asignacion
                   FROM public.asignacion_tripulacion""")
cert = consulta("""SELECT id_certificacion, id_tripulante, tipo_certificacion, numero_certificado,
                          fecha_emision, fecha_vencimiento, estado
                   FROM public.certificacion""")
lic = consulta("""SELECT id_tripulante, clase_medica, fecha_emision, fecha_vencimiento, estado
                  FROM public.licencia_medica""")

T = {int(t['id_tripulante']): t for t in trip}
V = {int(v['id_vuelo']): v for v in vuel}
for v in V.values():
    v['dur'] = (ts(v['llegada']) - ts(v['salida'])).total_seconds() / 3600


def equipo(v):
    """Tipo de aeronave según la duración del tramo (la aerolínea asigna el equipo por alcance)."""
    h, n = v['dur'], int(v['numero_vuelo'][2:])
    if h < 2.0:
        return 'A319'
    if h < 4.5:
        return 'A321' if n % 2 else 'B737-800'
    return 'B787-8'


for v in V.values():
    v['equipo'] = equipo(v)

por_trip = defaultdict(list)
for a in asig:
    por_trip[int(a['id_tripulante'])].append(a)
for lst in por_trip.values():
    lst.sort(key=lambda a: V[int(a['id_vuelo'])]['salida'])
por_vuelo = defaultdict(list)
for a in asig:
    por_vuelo[int(a['id_vuelo'])].append(a)

# ---------------------------------------------------------------------
# Nodos ancla (trazabilidad): Tripulante y Vuelo
# ---------------------------------------------------------------------
n_trip = [{'id_tripulante': int(t['id_tripulante']), 'numero_empleado': t['numero_empleado'], 'cargo': t['cargo'],
           'base': t['base'], 'region': t['region'], 'estado': t['estado']} for t in trip]
n_vuel = [{'id_vuelo': int(v['id_vuelo']), 'numero_vuelo': v['numero_vuelo'], 'origen': v['origen'],
           'destino': v['destino'], 'region_origen': v['region_origen'], 'salida': v['salida'].replace(' ', 'T'),
           'llegada': v['llegada'].replace(' ', 'T'), 'duracion_h': round(v['dur'], 2), 'equipo': v['equipo']}
          for v in V.values()]

# ---------------------------------------------------------------------
# 1. Pairing: rotación mensual de cada tripulante (descanso >= 10 h entre tramos)
# ---------------------------------------------------------------------
n_pair, r_opera, r_incluye, r_conecta = [], [], [], []
for idt, lst in por_trip.items():
    por_mes = defaultdict(list)
    for a in lst:
        por_mes[V[int(a['id_vuelo'])]['salida'][:7]].append(a)
    for mes, tramos in sorted(por_mes.items()):
        pid = f"P-{idt}-{mes}"
        vs = [V[int(a['id_vuelo'])] for a in tramos]
        horas = round(sum(float(a['horas_vuelo']) for a in tramos), 2)
        cortes = sum(1 for x, y in zip(vs, vs[1:]) if x['destino'] != y['origen'])
        p = {'id_pairing': pid, 'mes': mes, 'base': T[idt]['base'], 'num_tramos': len(tramos), 'horas_vuelo': horas,
             'inicio': vs[0]['salida'].replace(' ', 'T'), 'fin': vs[-1]['llegada'].replace(' ', 'T'),
             'equipos': sorted({v['equipo'] for v in vs})}
        if cortes:
            p['posicionamientos'] = cortes          # tramos donde el tripulante se reposiciona sin volar
        if vs[0]['origen'] == T[idt]['base'] and vs[-1]['destino'] == T[idt]['base']:
            p['cierra_en_base'] = True
        n_pair.append(p)
        r_opera.append({'id_tripulante': idt, 'id_pairing': pid, 'rol': tramos[0]['rol']})
        for k, a in enumerate(tramos, 1):
            r_incluye.append({'id_pairing': pid, 'id_vuelo': int(a['id_vuelo']), 'orden': k,
                              'id_asignacion': int(a['id_asignacion']), 'horas_vuelo': float(a['horas_vuelo'])})
        for x, y in zip(vs, vs[1:]):
            desc = round((ts(y['salida']) - ts(x['llegada'])).total_seconds() / 3600, 1)
            r_conecta.append({'de': int(x['id_vuelo']), 'a': int(y['id_vuelo']), 'id_pairing': pid,
                              'descanso_h': desc, 'mismo_aeropuerto': x['destino'] == y['origen']})

# ---------------------------------------------------------------------
# 2. Vínculo operativo: quién ha volado con quién (derivado de las asignaciones)
# ---------------------------------------------------------------------
pares = {}
for idv, crew in por_vuelo.items():
    ids = sorted(int(a['id_tripulante']) for a in crew)
    f = V[idv]['salida'][:10]
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            k = (ids[i], ids[j])
            e = pares.setdefault(k, {'a': ids[i], 'b': ids[j], 'vuelos_juntos': 0, 'primera_vez': f, 'ultima_vez': f,
                                      'ultimo_vuelo': idv})
            e['vuelos_juntos'] += 1
            if f < e['primera_vez']:
                e['primera_vez'] = f
            if f >= e['ultima_vez']:
                e['ultima_vez'], e['ultimo_vuelo'] = f, idv
r_volo = list(pares.values())

# ---------------------------------------------------------------------
# 3. Habilitación de equipo: tripulante–modelo de aeronave
# ---------------------------------------------------------------------
cert_por_trip = defaultdict(list)
for c in cert:
    cert_por_trip[int(c['id_tripulante'])].append(c)
n_hab, r_tiene = [], []
modelos = ['A319', 'A321', 'B737-800', 'B787-8']
for idt, t in T.items():
    flown = defaultdict(list)
    for a in por_trip.get(idt, []):
        v = V[int(a['id_vuelo'])]
        flown[v['equipo']].append(v['salida'][:10])
    cabina = t['cargo'] in ('PILOTO', 'COPILOTO')
    ht = sorted((c for c in cert_por_trip[idt] if c['tipo_certificacion'] == 'HABILITACION_TIPO'),
                key=lambda c: c['fecha_emision'])
    primero = True
    for eq in sorted(flown, key=lambda e: min(flown[e])):
        prim_vuelo = d(min(flown[eq]))
        emi = prim_vuelo - timedelta(days=random.randint(60, 900))
        h = {'id_habilitacion': f"H-{idt}-{eq}", 'id_tripulante': idt, 'equipo': eq,
             'tipo': 'TYPE_RATING' if cabina else 'FAMILIARIZACION', 'fecha_emision': emi.isoformat(),
             'estado': 'VIGENTE'}
        if cabina:
            h['fecha_vencimiento'] = (d(max(flown[eq])) + timedelta(days=random.randint(120, 500))).isoformat()
            h['horas_en_equipo'] = random.randint(300, 6000)
            if primero and ht:
                h['id_certificacion'] = int(ht[-1]['id_certificacion'])   # certificación relacional que la respalda
        else:
            h['puertas_entrenadas'] = {'A319': 4, 'A321': 6, 'B737-800': 4, 'B787-8': 8}[eq]
        primero = False
        n_hab.append(h)
        r_tiene.append({'id_tripulante': idt, 'id_habilitacion': h['id_habilitacion'], 'desde': h['fecha_emision']})
    # habilitaciones en curso o vencidas en equipos que no vuela (diversidad del dominio)
    if random.random() < 0.15:
        libres = [m for m in modelos if m not in flown]
        if libres:
            eq = random.choice(libres)
            emi = date(2026, 1, 1) + timedelta(days=random.randint(0, 170))
            h = {'id_habilitacion': f"H-{idt}-{eq}", 'id_tripulante': idt, 'equipo': eq,
                 'tipo': 'TYPE_RATING' if cabina else 'FAMILIARIZACION',
                 'fecha_emision': emi.isoformat(), 'estado': 'EN_ENTRENAMIENTO',
                 'fase': random.choice(['TEORIA', 'SIMULADOR', 'LINEA_SUPERVISADA'])}
            n_hab.append(h)
            r_tiene.append({'id_tripulante': idt, 'id_habilitacion': h['id_habilitacion'], 'desde': h['fecha_emision']})

# ---------------------------------------------------------------------
# 4. Instrucción: cada certificación relacional nace de una sesión de instrucción
# ---------------------------------------------------------------------
GRUPO = {'PILOTO': 'cabina', 'COPILOTO': 'cabina', 'JEFE_CABINA': 'pasajeros', 'AUXILIAR_VUELO': 'pasajeros'}
MODAL = {'LICENCIA_ATP': 'SIMULADOR', 'HABILITACION_TIPO': 'SIMULADOR', 'CRM': 'AULA',
         'SEGURIDAD_CABINA': 'PRACTICA', 'PRIMEROS_AUXILIOS': 'AULA', 'MERCANCIAS_PELIGROSAS': 'E_LEARNING'}
vigentes = defaultdict(list)          # tipo -> [(id_trip, emision, vencimiento)]
for c in cert:
    vigentes[c['tipo_certificacion']].append((int(c['id_tripulante']), d(c['fecha_emision']), d(c['fecha_vencimiento'])))
n_inst, r_imparte, r_recibe, r_otorga = [], [], [], []
hab_por_trip = defaultdict(list)
for h in n_hab:
    hab_por_trip[h['id_tripulante']].append(h)
for c in sorted(cert, key=lambda c: c['fecha_emision']):
    idt, tipo = int(c['id_tripulante']), c['tipo_certificacion']
    fecha = d(c['fecha_emision']) - timedelta(days=random.randint(1, 20))
    mod = MODAL[tipo]
    i = {'id_instruccion': f"I-{c['id_certificacion']}", 'id_certificacion': int(c['id_certificacion']),
         'curso': tipo, 'modalidad': mod, 'fecha': fecha.isoformat(), 'resultado': 'APROBADO'}
    if mod == 'SIMULADOR':
        i['horas_simulador'] = random.choice([4, 4, 8, 12])
        eqs = [h['equipo'] for h in hab_por_trip[idt] if h['tipo'] == 'TYPE_RATING']
        if eqs:
            i['equipo'] = random.choice(eqs)
        i['maniobras'] = random.sample(['FALLA_MOTOR_V1', 'APROXIMACION_ILS', 'ESCAPE_CIZALLADURA',
                                        'ATERRIZAJE_MANUAL', 'DESPRESURIZACION', 'APROXIMACION_FRUSTRADA'], 3)
    elif mod == 'AULA':
        i['horas_aula'] = random.choice([4, 6, 8, 16])
        i['sala'] = f"{T[idt]['base']}-AULA-{random.randint(1, 4)}"
    elif mod == 'PRACTICA':
        i['ejercicios'] = random.sample(['EVACUACION', 'AMARIZAJE', 'FUEGO_EN_CABINA', 'RCP', 'PASAJERO_DISRUPTIVO'], 2)
        i['horas_practica'] = random.choice([3, 4, 6])
    else:
        i['plataforma'] = 'LMS'
        i['puntaje'] = random.randint(80, 100)
    n_inst.append(i)
    r_recibe.append({'id_tripulante': idt, 'id_instruccion': i['id_instruccion']})
    if mod != 'E_LEARNING':
        # instructor: mismo grupo, más antiguo, con la misma certificación vigente en la fecha
        cand = [x for x, emi, ven in vigentes[tipo]
                if x != idt and GRUPO[T[x]['cargo']] == GRUPO[T[idt]['cargo']]
                and T[x]['cargo'] in ('PILOTO', 'JEFE_CABINA')
                and emi <= fecha <= ven and T[x]['fecha_ingreso'] < T[idt]['fecha_ingreso']]
        misma_base = [x for x in cand if T[x]['base'] == T[idt]['base']]
        cand = sorted(set(misma_base or cand))
        if cand:
            # pocos instructores por base: se toma uno de los tres más antiguos
            cand.sort(key=lambda x: T[x]['fecha_ingreso'])
            ins = random.choice(cand[:3])
            r_imparte.append({'id_tripulante': ins, 'id_instruccion': i['id_instruccion']})
    if tipo == 'HABILITACION_TIPO':
        th = [h for h in hab_por_trip[idt] if h.get('id_certificacion') == int(c['id_certificacion'])]
        if th:
            r_otorga.append({'id_instruccion': i['id_instruccion'], 'id_habilitacion': th[0]['id_habilitacion']})

# ---------------------------------------------------------------------
# 5. Cadena de reemplazo: titular planificado -> sustituto (quien voló según la asignación real)
# ---------------------------------------------------------------------
lic_por_trip = defaultdict(list)
for l in lic:
    lic_por_trip[int(l['id_tripulante'])].append(l)


def vuela_ese_dia(idt, dia):
    return any(V[int(a['id_vuelo'])]['salida'][:10] == dia for a in por_trip.get(idt, []))


def sin_licencia(idt, dia):
    return not any(l['fecha_emision'] <= dia <= l['fecha_vencimiento'] and l['estado'] != 'SUSPENDIDA'
                   for l in lic_por_trip[idt])


r_reemp = []
por_dia_cargo = defaultdict(list)       # (dia, cargo) -> [(salida, asignacion)]
for a in asig:
    v = V[int(a['id_vuelo'])]
    por_dia_cargo[(v['salida'][:10], a['rol'])].append((v['salida'], a))
claves = [k for k, lst in por_dia_cargo.items() if len(lst) >= 2]
random.shuffle(claves)
usados = set()
cadena_n = 0
for dia, cargo in claves:
    if len(r_reemp) >= 120:
        break
    lst = sorted(por_dia_cargo[(dia, cargo)], key=lambda x: x[0])
    largo = random.choice([1, 1, 2, 2, 3, 4])
    eslabones = [a for _, a in lst[:largo] if int(a['id_tripulante']) not in usados]
    if not eslabones:
        continue
    base = T[int(eslabones[0]['id_tripulante'])]['base']
    titulares = [x for x, t in T.items() if t['cargo'] == cargo and not vuela_ese_dia(x, dia) and x not in usados]
    if not titulares:
        continue
    cadena_n += 1
    prefer = [x for x in titulares if T[x]['base'] == base] or titulares
    titular = random.choice(prefer)
    if sin_licencia(titular, dia):
        motivo = 'CERTIFICADO_MEDICO_VENCIDO'
    else:
        motivo = random.choice(['ENFERMEDAD', 'ENFERMEDAD', 'FATIGA', 'RETRASO_EN_CONEXION', 'EMERGENCIA_FAMILIAR'])
    previo = titular
    for k, a in enumerate(eslabones, 1):
        sust = int(a['id_tripulante'])
        r = {'de': previo, 'a': sust, 'id_cadena': f"C-{cadena_n:03d}", 'eslabon': k, 'fecha': dia,
             'id_vuelo': int(a['id_vuelo']), 'id_asignacion': int(a['id_asignacion']),
             'motivo': motivo if k == 1 else 'REASIGNADO_A_OTRO_VUELO', 'aviso_horas': random.choice([2, 4, 6, 12, 24])}
        r_reemp.append(r)
        usados.update({previo, sust})
        previo = sust


# ---------------------------------------------------------------------
# Escritura de los scripts Cypher (lotes UNWIND con datos literales)
# ---------------------------------------------------------------------
def lit(x):
    if isinstance(x, bool):
        return 'true' if x else 'false'
    if isinstance(x, (int, float)):
        return repr(x)
    if isinstance(x, list):
        return '[' + ', '.join(lit(y) for y in x) + ']'
    if isinstance(x, dict):
        return '{' + ', '.join(f"{k}: {lit(v)}" for k, v in x.items()) + '}'
    return "'" + str(x).replace('\\', '\\\\').replace("'", "\\'") + "'"


def bloques(filas, cuerpo, tam=400):
    out = []
    for k in range(0, len(filas), tam):
        out.append('UNWIND [\n  ' + ',\n  '.join(lit(f) for f in filas[k:k + tam]) + '\n] AS row\n' + cuerpo + ';\n')
    return '\n'.join(out)


FECHAS = {'fecha_emision', 'fecha_vencimiento', 'fecha', 'primera_vez', 'ultima_vez', 'desde'}
DT = {'salida', 'llegada', 'inicio', 'fin'}


def set_props(var, campos):
    partes = []
    for c in campos:
        if c in FECHAS:
            partes.append(f"{var}.{c} = CASE WHEN row.{c} IS NULL THEN null ELSE date(row.{c}) END")
        elif c in DT:
            partes.append(f"{var}.{c} = localdatetime(row.{c})")
        else:
            partes.append(f"{var}.{c} = row.{c}")
    return ', '.join(partes)


def campos(filas, excluir=()):
    vistos = []
    for f in filas:
        for k in f:
            if k not in vistos and k not in excluir:
                vistos.append(k)
    return vistos


nodos = ['// Carga de nodos (generado desde el staging de la Unidad 1)\n']
nodos.append('// Tripulante (ancla hacia public.tripulante)\n' + bloques(
    n_trip, 'MERGE (t:Tripulante {id_tripulante: row.id_tripulante})\nSET ' + set_props('t', campos(n_trip, ['id_tripulante']))))
nodos.append('// Vuelo (ancla hacia public.vuelo)\n' + bloques(
    n_vuel, 'MERGE (v:Vuelo {id_vuelo: row.id_vuelo})\nSET ' + set_props('v', campos(n_vuel, ['id_vuelo']))))
nodos.append('// Pairing\n' + bloques(
    n_pair, 'MERGE (p:Pairing {id_pairing: row.id_pairing})\nSET ' + set_props('p', campos(n_pair, ['id_pairing']))))
nodos.append('// Habilitacion\n' + bloques(
    n_hab, 'MERGE (h:Habilitacion {id_habilitacion: row.id_habilitacion})\nSET ' + set_props('h', campos(n_hab, ['id_habilitacion']))))
nodos.append('// Instruccion\n' + bloques(
    n_inst, 'MERGE (i:Instruccion {id_instruccion: row.id_instruccion})\nSET ' + set_props('i', campos(n_inst, ['id_instruccion']))))
(OUT / '02_nodos.cypher').write_text('\n'.join(nodos), encoding='utf-8')

rels = ['// Carga de relaciones (generado desde el staging de la Unidad 1)\n']
rels.append('// (:Tripulante)-[:OPERA]->(:Pairing)\n' + bloques(r_opera,
    'MATCH (t:Tripulante {id_tripulante: row.id_tripulante}), (p:Pairing {id_pairing: row.id_pairing})\n'
    'MERGE (t)-[r:OPERA]->(p) SET r.rol = row.rol'))
rels.append('// (:Pairing)-[:INCLUYE]->(:Vuelo)\n' + bloques(r_incluye,
    'MATCH (p:Pairing {id_pairing: row.id_pairing}), (v:Vuelo {id_vuelo: row.id_vuelo})\n'
    'MERGE (p)-[r:INCLUYE]->(v) SET r.orden = row.orden, r.id_asignacion = row.id_asignacion, r.horas_vuelo = row.horas_vuelo'))
rels.append('// (:Vuelo)-[:CONECTA_CON]->(:Vuelo) dentro de un pairing\n' + bloques(r_conecta,
    'MATCH (a:Vuelo {id_vuelo: row.de}), (b:Vuelo {id_vuelo: row.a})\n'
    'MERGE (a)-[r:CONECTA_CON {id_pairing: row.id_pairing}]->(b) SET r.descanso_h = row.descanso_h, r.mismo_aeropuerto = row.mismo_aeropuerto'))
rels.append('// (:Tripulante)-[:VOLO_CON]->(:Tripulante)\n' + bloques(r_volo,
    'MATCH (a:Tripulante {id_tripulante: row.a}), (b:Tripulante {id_tripulante: row.b})\n'
    'MERGE (a)-[r:VOLO_CON]->(b) SET r.vuelos_juntos = row.vuelos_juntos, r.primera_vez = date(row.primera_vez), '
    'r.ultima_vez = date(row.ultima_vez), r.ultimo_vuelo = row.ultimo_vuelo', 800))
rels.append('// (:Tripulante)-[:TIENE_HABILITACION]->(:Habilitacion)\n' + bloques(r_tiene,
    'MATCH (t:Tripulante {id_tripulante: row.id_tripulante}), (h:Habilitacion {id_habilitacion: row.id_habilitacion})\n'
    'MERGE (t)-[r:TIENE_HABILITACION]->(h) SET r.desde = date(row.desde)'))
rels.append('// (:Tripulante)-[:RECIBE]->(:Instruccion)\n' + bloques(r_recibe,
    'MATCH (t:Tripulante {id_tripulante: row.id_tripulante}), (i:Instruccion {id_instruccion: row.id_instruccion})\n'
    'MERGE (t)-[:RECIBE]->(i)'))
rels.append('// (:Tripulante)-[:IMPARTE]->(:Instruccion)\n' + bloques(r_imparte,
    'MATCH (t:Tripulante {id_tripulante: row.id_tripulante}), (i:Instruccion {id_instruccion: row.id_instruccion})\n'
    'MERGE (t)-[:IMPARTE]->(i)'))
rels.append('// (:Instruccion)-[:OTORGA]->(:Habilitacion)\n' + bloques(r_otorga,
    'MATCH (i:Instruccion {id_instruccion: row.id_instruccion}), (h:Habilitacion {id_habilitacion: row.id_habilitacion})\n'
    'MERGE (i)-[:OTORGA]->(h)'))
rels.append('// (:Tripulante)-[:REEMPLAZADO_POR]->(:Tripulante)\n' + bloques(r_reemp,
    'MATCH (a:Tripulante {id_tripulante: row.de}), (b:Tripulante {id_tripulante: row.a})\n'
    'MERGE (a)-[r:REEMPLAZADO_POR {id_asignacion: row.id_asignacion}]->(b)\n'
    'SET r.id_cadena = row.id_cadena, r.eslabon = row.eslabon, r.fecha = date(row.fecha), r.id_vuelo = row.id_vuelo, '
    'r.motivo = row.motivo, r.aviso_horas = row.aviso_horas'))
(OUT / '03_relaciones.cypher').write_text('\n'.join(rels), encoding='utf-8')

resumen = {'Tripulante': len(n_trip), 'Vuelo': len(n_vuel), 'Pairing': len(n_pair), 'Habilitacion': len(n_hab),
           'Instruccion': len(n_inst), 'OPERA': len(r_opera), 'INCLUYE': len(r_incluye), 'CONECTA_CON': len(r_conecta),
           'VOLO_CON': len(r_volo), 'TIENE_HABILITACION': len(r_tiene), 'RECIBE': len(r_recibe),
           'IMPARTE': len(r_imparte), 'OTORGA': len(r_otorga), 'REEMPLAZADO_POR': len(r_reemp), 'cadenas': cadena_n}
print(json.dumps(resumen, indent=1))
