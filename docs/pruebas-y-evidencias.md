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

Resultado SQL local: creación de base `BI_OLIST` desde ausencia previa; ejecución satisfactoria de scripts 00–06; reejecución satisfactoria de 00–05 sin borrar filas; prueba 06 terminó en `PASS` con cambios revertidos. Al momento de la prueba los controles informaron cero filas porque las fuentes aún no se han cargado a staging/DW. La base local queda creada, sin datos cargados.

Evidencia académica pendiente: (1) origen, términos/licencia y versión/fecha; (2) ejecución SQL de DDL, reejecución, constraints y pruebas; (3) SSIS ingesta y transformación, conteos, rechazos e idempotencia; (4) SSAS, procesamiento y cotejo DAX/SQL; (5) Power BI Live, cuatro páginas y filtros; (6) conclusiones solo con resultados integrados. Las fixtures son sintéticas y no prueban hallazgos de Olist.
