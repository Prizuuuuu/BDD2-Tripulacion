# Mediciones de las consultas distribuidas

Obtenidas con `medir_estrategias.py`: 1 ejecución de calentamiento y 15 medidas por estrategia,
mediana del `Execution Time` de `EXPLAIN ANALYZE`. Clúster de 4 contenedores en un mismo equipo
(latencia de red menor a 1 ms).

| Variante | Estrategia | Mediana | Mínimo | Máximo |
|---|---|---|---|---|
| 1A | Co-located join + tablas de referencia | 3,60 ms | 3,00 ms | 5,03 ms |
| 1B | Repartition join | 270,93 ms | 264,67 ms | 292,24 ms |
| 1C | Router (solo región ESTE) | 2,46 ms | 2,17 ms | 3,23 ms |
| 1D | Staging central (Unidad 1) | 1,89 ms | 1,80 ms | 2,62 ms |
| 2A | Repartition join | 280,06 ms | 262,90 ms | 299,75 ms |
| 2B | Gather en el coordinador | 17,59 ms | 16,93 ms | 18,99 ms |
| 2C | Staging central (Unidad 1) | 3,56 ms | 3,34 ms | 4,11 ms |

Consulta 1: horas de vuelo acumuladas por base operativa.
Consulta 2: horas por región base del tripulante y región de operación del vuelo.

## Datos recibidos por el coordinador (EXPLAIN ANALYZE)

| Variante | Tareas | Datos |
|---|---|---|
| 1A | 3 | 278 bytes |
| 1B | 3 map + 16 merge | 3.973 bytes (más el intercambio entre workers) |
| 1C | 1 | 138 bytes |
| 2A | 3 map + 16 merge | 4.414 bytes (más el intercambio entre workers) |
| 2B | 3 + 3 + 1 | 172 kB recibidos, 300 kB de resultados intermedios enviados a los nodos |

## Costo de comunicación estimado

`T = mensajes × 30 ms + bytes / 12,5 MB/s` (enlace WAN de 100 Mbps entre regiones).

| Variante | Mensajes | Bytes | T estimado |
|---|---|---|---|
| 1A co-located | 6 | ≈ 2,1 kB | ≈ 0,18 s |
| 1C router | 2 | ≈ 0,7 kB | ≈ 0,06 s |
| 1B repartition | 230 | ≈ 96,8 kB | ≈ 6,91 s |
| 2A repartition | 230 | ≈ 147,4 kB | ≈ 6,91 s |
| 2B gather | 20 | ≈ 1.072 kB | ≈ 0,69 s |
