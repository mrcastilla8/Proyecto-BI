# Pruebas y evidencias

CI ejecuta las validaciones Python sin dataset privado. En Windows se usa `python scripts/validar_base.py` y `python -m unittest discover -s scripts -p "test_*.py" -v`. SQL se prueba localmente con `sqlcmd -S .\\SQLEXPRESS -E -C -i database\\00_crear_base.sql` y en orden los scripts 01 a 06; `-C` confía en el certificado del motor local. CI no ejecuta SQL, SSIS, SSAS ni Power BI. El script de perfilado Python es diagnóstico de archivos locales, no ETL.

## Perfil local observado (18-11-2026)

Origen indicado por el responsable: carpeta local `dataset_bi`, nueve CSV. No se incorpora ningún archivo ni fila al repositorio. La ejecución registró SHA-256 por archivo en la salida local del perfil; el comando repetible es `python scripts/perfilar_dataset.py <carpeta_csv>`. Codificación observada: UTF-8, BOM opcional; separador coma y comillas dobles; campos con acentos se decodifican correctamente. Fechas y timestamps observados usan `YYYY-MM-DD HH:MM:SS`; montos usan punto decimal y hasta dos decimales. No se detectaron filas con longitudes irregulares en `csv.DictReader`.

| Archivo | Filas | Vacíos destacados | Observación de clave candidata |
|---|---:|---|---|
| orders | 99,441 | approved 160; entrega transportista 1,783; entrega cliente 2,965 | `order_id` único |
| order_items | 112,650 | ninguno | `(order_id, order_item_id)` único |
| order_payments | 103,886 | ninguno | `(order_id, payment_sequential)` único |
| order_reviews | 99,224 | título 87,656; comentario 58,247 | 0 filas exactas repetidas; 814 filas excedentes por `review_id`, multiplicidad máxima 3 |
| customers | 99,441 | ninguno | `customer_id` único; `customer_unique_id` tiene 96,096 valores distintos |
| sellers | 3,095 | ninguno | `seller_id` único |
| products | 32,951 | categoría y tres atributos descriptivos: 610 cada uno; dimensiones físicas: 2 cada una | `product_id` único; origen usa literalmente `product_name_lenght` y `product_description_lenght` |
| geolocation | 1,000,163 | ninguno | 261,831 filas exactas repetidas; prefijo postal: 19,015 valores para 1,000,163 filas; no unir directamente |
| product category translation | 71 | ninguno | nombre de categoría único |

Los demás archivos no tienen filas exactas repetidas; claves candidatas únicas excepto `review_id`. Valores de coordenadas exceden rangos geográficos esperados; permanecen fuera del modelo analítico. Las reseñas repetidas se retienen en staging; no se resuelve conflicto por descarte arbitrario. Las consultas de negocio no se ejecutaron contra datos cargados al DW. Fuente de descarga y licencia/condiciones de uso requieren comprobación documental del responsable. El SQL Server local detectado es 2025 Express 17.0.1000.7; conexión Windows integrada a `SQLEXPRESS` funciona con `sqlcmd -C`.

El perfilador transmite los bytes CSV a SHA-256 mientras el parser decodifica una sola vez; mínimos, máximos y escala decimal se acumulan incrementalmente. Se ejecutó dos veces sobre los nueve archivos originales y ambos informes agregados tuvieron SHA-256 idéntico `0e9eb01430cef34bd15d9fcdecdfa56c032f8f84c51826586899369711aec312`. Los informes se mantuvieron fuera de Git.

Verificación local de cierre (18-11-2026): en Windows, `sqlcmd -S .\SQLEXPRESS -E -C -b -i database\00_crear_base.sql` y los scripts 01–05 terminaron sin error sobre la base existente; `database\06_pruebas.sql` imprimió `PASS` y revirtió sus cambios. La reejecución de 00–05 terminó sin error. La inspección de metadatos confirmó 9 tablas `stg`, 8 tablas `dw`, 2 tablas `audit`, 9 índices únicos `(batch_id, source_row_number)`, 21 claves foráneas y los 6 miembros desconocidos; los contadores de lote estaban vacíos y el conteo agregado de filas en staging/hechos fue 0. La versión observada fue SQL Server 2025 Express 17.0.1000.7. No se cargaron los CSV a staging/DW.

Validación local de compatibilidad CSV (18-11-2026): el perfilador y el control automatizado específico recorrieron una vez los nueve archivos, sin guardar filas originales en el repositorio. PASS para longitudes de texto medidas en unidades UTF-16 de SQL Server, DECIMAL (precisión y escala), INT/TINYINT, timestamps parseables como `DATETIME2(0)`, vacíos solo en columnas nullable, y multiplicidades de claves candidatas. `review_score` tuvo valores no nulos 1–5 y cero vacíos. `review_id` no se trató como clave candidata; se observaron 814 filas excedentes y máximo 3 apariciones. El resumen agregado reproducible tuvo SHA-256 `de17ac37d50c66bdce38f119045c6fc717f0b9ff11fe02bea7e59b9936deebf3`. No hubo incompatibilidad física observada para futura carga; no se cargaron los CSV a staging/DW.

Resultado SQL local: la migración se aplicó a la base `BI_OLIST` existente sin recrearla. La ejecución satisfactoria de scripts 00–06 y la reejecución 00–05 se registran para el HEAD del PR. `06` terminó en `PASS`: unicidad de ordinales en las nueve tablas, repetidos de origen conservados, repetición del mismo ordinal rechazada, contadores parciales permitidos en estados no terminales, contadores incompletos rechazados en `COMPLETE`, transiciones válidas e inválidas y finalización coherente; también los controles de grano/FK, importes, fechas y casos negativos con rollback. Los controles informaron cero filas porque los CSV aún no se cargaron a staging/DW. La base local no contiene datos de ETL.

Evidencia de integración pendiente: (1) SSIS ingesta y transformación, conteos, rechazos e idempotencia; (2) SSAS, procesamiento y cotejo DAX/SQL; (3) Power BI Live, páginas y filtros; (4) conclusiones solo con resultados integrados. Las fixtures son sintéticas y no prueban hallazgos de Olist.

## Nivel 2 — OLIST 360° (casos de certificación pendientes)

El plan de certificación del Nivel 2 se encuentra especificado en [08_PRUEBAS_CERTIFICACION.md](nivel-2/08_PRUEBAS_CERTIFICACION.md) y contempla un checklist independiente de preflight (`G0`: `PRE-G0-01`..`PRE-G0-08`) y **29 casos de certificación** para `G3`/`G4`, **todos actualmente en estado `NOT_RUN`** (sin ejecución práctica ni instalación de SSRS en esta etapa documental):

- `BASE-01` a `BASE-03` (3 casos): integridad del alcance congelado, validadores Python y conciliación baseline SQL/DAX.
- `PBI-01` a `PBI-09` (9 casos): conexión Live, 8 páginas visibles, 7 auxiliares (4 tooltips + 3 drill-through), filtros sincronizados, contexto detalle/cabecera, panel/reset, Shape Map (27 UF) y casos límite.
- `SSRS-01` a `SSRS-14` (14 casos): versión/catálogo/portal con 10 RDL publicados, seguridad Windows/Browser/solo lectura, validación funcional y numérica de `R01`–`R10`, guardas de parámetros y exportaciones 10/10 PDF y XLSX.
- `INT-01` a `INT-03` (3 casos): navegación Power BI → SSRS (`P08` y `P01`–`P07`), drill-through `R05` → `R08` y reproducción en equipo demo.
