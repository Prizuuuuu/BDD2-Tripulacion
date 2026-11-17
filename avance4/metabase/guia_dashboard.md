# Dashboard en Metabase · «Tripulación: control operativo» (Grupo 5)

Conexión: **Admin → Bases de datos → Agregar** → MySQL · Nombre `Data Mart Tripulación` · Host `mysql_dm` · Puerto `3306` ·
Base `dm_tripulacion` · Usuario `root` · Contraseña `0000`. (Host `mysql_dm` porque Metabase corre en la misma red de Docker.)
Si en «Opciones adicionales» pide algo, agrega `allowPublicKeyRetrieval=true&useSSL=false`.

Cada tarjeta es una **pregunta SQL nativa** (Nuevo → Consulta SQL). Después de pegar el SQL, abre el panel de variables (ícono `{x}`)
y configura cada variable como **Tipo: Filtro de campo** apuntando al campo indicado. Así el filtro del dashboard la controla.

| Variable | Tipo | Campo al que apunta | Widget |
|---|---|---|---|
| `fecha` | Filtro de campo | la columna `fecha` de la vista de la tarjeta | Fecha → Todas las opciones |
| `region` | Filtro de campo | la columna `region` (o `region_base`) de la vista | Categoría |

## Tarjetas (en este orden en el tablero)

### 1. Cumplimiento de jornada máxima (KPI · Número)
```sql
SELECT ROUND(100 * AVG(cumple_jornada_maxima), 2) AS "Cumplimiento (%)"
FROM v_jornadas WHERE {{fecha}} AND {{region}}
```
`fecha` → v_jornadas.fecha · `region` → v_jornadas.region. Sin filtros: **99,71 %**.
Descripción: «% de jornadas con ≤ 13 h de servicio, ≥ 10 h de descanso previo y ≤ 60 h en 7 días».

### 2. Reemplazos de última hora (KPI · Número)
```sql
SELECT ROUND(100 * SUM(reemplazo_ultima_hora) / COUNT(*), 2) AS "Reemplazos con aviso ≤ 6 h (% de asignaciones)"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
```
`fecha` → v_asignaciones.fecha · `region` → v_asignaciones.region. Sin filtros: **1,31 %** (72 de 5.500).

### 3. Credenciales por vencer en 90 días (KPI · Número)
```sql
SELECT SUM(proxima_a_vencer_90d) AS "Credenciales por vencer (90 días)"
FROM v_credenciales WHERE {{region}}
```
`region` → v_credenciales.region (región de la base). Sin filtros: **248** (166 tripulantes).

### 4. Tripulantes por vuelo (KPI · Número)
```sql
SELECT ROUND(COUNT(*) / COUNT(DISTINCT sk_vuelo), 2) AS "Tripulantes por vuelo"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
```
Sin filtros: **5,00** (1 piloto, 1 copiloto, 1 jefe de cabina, 2 auxiliares).

### 5. Carga por base: horas de vuelo por tripulante (Barras horizontales)
```sql
SELECT base AS "Base", ROUND(SUM(horas_vuelo) / COUNT(DISTINCT sk_tripulante), 1) AS "Horas por tripulante",
       SUM(horas_vuelo) AS "Horas totales"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
GROUP BY base ORDER BY 2 DESC
```
`region` → v_asignaciones.**region_base**. Eje Y: «Horas por tripulante». Sin filtros: ORD 46,0 h arriba, DCA 42,7 h abajo.

### 6. Reemplazos por mes (Línea)
```sql
SELECT mes AS "Mes", SUM(reemplazo_ultima_hora) AS "De última hora (≤ 6 h)", SUM(es_reemplazo) AS "Todos los reemplazos"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
GROUP BY mes ORDER BY mes
```
Pico en abril 2026 (18 de última hora de 29).

### 7. ¿Quién cubre los vuelos de cada región? (Barras apiladas 100 %) — HALLAZGO
```sql
SELECT region AS "Región de salida",
       CASE WHEN fuera_region_base = 0 THEN 'Tripulación de la región' ELSE 'Tripulación de otra región' END AS "Cobertura",
       COUNT(*) AS "Puestos"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
GROUP BY 1, 2 ORDER BY 1, 2
```
Visualización: Barras → Apilado → «Apilar al 100 %». Oeste: solo **19,6 %** cubierto por tripulación local.

### 8. Credenciales que vencen en el 2.º semestre 2026 (Barras apiladas por tipo)
```sql
SELECT mes_vencimiento AS "Mes de vencimiento", credencial AS "Credencial", COUNT(*) AS "Vencen"
FROM v_credenciales
WHERE estado = 'Vigente' AND fecha_vencimiento BETWEEN '2026-07-01' AND '2026-12-31' AND {{region}}
GROUP BY 1, 2 ORDER BY 1
```
Crece de 67 (julio) a 128 (noviembre).

### 9. Top 10 tripulantes por horas acumuladas (Tabla)
```sql
SELECT tripulante AS "Tripulante", cargo AS "Cargo", base AS "Base", SUM(horas_vuelo) AS "Horas de vuelo"
FROM v_asignaciones WHERE {{fecha}} AND {{region}}
GROUP BY tripulante, cargo, base ORDER BY 4 DESC LIMIT 10
```

## Filtros del tablero
1. Editar tablero → **Agregar filtro → Fecha → Todas las opciones**, nombre «Período». Conéctalo a la variable `fecha` de las tarjetas 1, 2, 4, 5, 6, 7 y 9.
2. **Agregar filtro → Texto o categoría**, nombre «Región». Conéctalo a la variable `region` de todas las tarjetas.
3. Guarda. Prueba: Período = «Trimestre anterior» no aplica (los datos son de 2026-01 a 2026-06): usa «Entre 2026-04-01 y 2026-06-30»
   → reemplazos de última hora sube a **1,52 %** (en el 1.er trimestre era 1,10 %).

## Distribución sugerida (cuadrícula de 24 columnas)
Fila 1: tarjetas 1–4 (6 columnas cada una, alto 3). Fila 2: tarjeta 7 (12 col) y tarjeta 5 (12 col). Fila 3: tarjeta 6 (12 col) y
tarjeta 8 (12 col). Fila 4: tarjeta 9 (24 col). Agrega un texto arriba: «Datos: enero–junio 2026 · Fuente: Data Mart dm_tripulacion».

## Instancia local ya configurada (PC de Cesar)
El tablero ya está creado en http://localhost:3000/dashboard/2 (usuario local de prueba solo en el contenedor de Metabase de esa PC).
