# Entrega de staging a Axel

La carga inicial del 20 de noviembre de 2026 quedó confirmada en `BI_OLIST` del servicio **MSSQLSERVER**, instancia predeterminada local de SQL Server 2025. Los nueve lotes auténticos están `COMPLETE`. El maestro dejó 1.550.922 filas aceptadas y cero rechazos. Una segunda ejecución conservó los lotes, los conteos y las fechas. Las bases LocalDB se usaron para validar fixtures, rollback y la corrección de texto. Sus IDs y resultados sintéticos son independientes.

## Lotes y granos de origen

Los tipos, longitudes, escalas y nulos semánticos se rigen por el [contrato 1.0.0](../../contracts/modelo-dimensional.v1.json). Algunas columnas físicas de staging admiten NULL para ingestión. La [definición SQL](../../database/02_staging.sql) y la auditoría permiten comprobar el conjunto publicado.

| Tabla `stg` | Lote | Filas | Grano y columnas que usa transformación |
| --- | ---: | ---: | --- |
| Orders | 7 | 99.441 | Registro de pedido. `order_id`, `customer_id`, estado y fechas `DATETIME2(0)`. Aprobación y dos fechas de entrega pueden ser NULL. |
| OrderItems | 8 | 112.650 | Línea del pedido por `order_id` y `order_item_id`. Conserva producto, vendedor, fecha límite, precio y flete `DECIMAL(19,4)`. |
| OrderPayments | 9 | 103.886 | Registro de pago por `order_id` y `payment_sequential`. Incluye tipo, cuotas y valor `DECIMAL(19,4)`. |
| OrderReviews | 10 | 99.224 | Registro de reseña asociado a `order_id`. `review_id` puede repetirse. Puntuación, fechas, título `NVARCHAR(1000)` y comentario `NVARCHAR(4000)` admiten NULL. |
| Customers | 11 | 99.441 | Registro por `customer_id`. `customer_unique_id` vincula registros del mismo cliente. Prefijo postal `CHAR(5)`, ciudad Unicode y estado `CHAR(2)`. |
| Sellers | 12 | 3.095 | Registro de vendedor por `seller_id`. Prefijo postal `CHAR(5)`, ciudad Unicode y estado `CHAR(2)`. |
| Products | 13 | 32.951 | Registro por `product_id`. Categoría Unicode, recuentos enteros y medidas `DECIMAL(12,3)` opcionales. Se conservan los nombres `product_name_lenght` y `product_description_lenght`. |
| Geolocation | 14 | 1.000.163 | Observación geográfica por fila de origen. El prefijo postal admite muchas observaciones. Latitud `DECIMAL(24,20)`, longitud `DECIMAL(24,16)`, ciudad y estado. |
| ProductCategoryTranslation | 15 | 71 | Registro de traducción con nombre de categoría y traducción `NVARCHAR(200)`. |

La clave técnica de origen es `(batch_id, source_row_number)`. Staging preserva duplicados legítimos, incluido el detalle geográfico y la repetición de `review_id`. **La deduplicación y la consolidación analítica corresponden a transformación**, según el contrato. En Reviews, la publicación mantiene Unicode, espacios finales y registros multilínea. El texto de cero bytes se publica como NULL donde se admite.

## Comprobar y consumir

1. Configura el servidor autorizado y la base `BI_OLIST` en la conexión de transformación. La identidad integrada usada para validar el laboratorio y la instancia principal pudo leer todas las tablas y la vista. El acceso de una identidad distinta para Axel queda por verificar. Usa una cuenta con `SELECT` en `stg` y `audit.vw_BatchStatus` y las autorizaciones de Data Mart que correspondan al trabajo de transformación. Esta entrega no concede permisos ni comparte datos de acceso.
2. Ejecuta la [consulta de disponibilidad y conciliación](generador/sql/consultas-principal.sql) en la instancia principal. Espera nueve filas `COMPLETE` en la primera cuadrícula y nueve valores `SI` en la segunda. Aplica los IDs confirmados de arriba si el consumo debe reproducir esta carga concreta.
3. `audit.Batch` identifica cada archivo por fuente, nombre, SHA-256 y versión. `audit.Reject` incluye los rechazos por lote y ordinal. Verifica que las filas de staging coincidan con `rows_accepted`; consume lotes confirmados.
4. Para reejecutar la ingesta, usa el mismo maestro y configura `CSV_ROOT`, `SQL_SERVER` y `SQL_DATABASE` solo en una copia local. DTExec x64 verifica el mismo hash y omite los lotes confirmados. Comprueba los conteos y fechas antes y después. [Procedimiento y versiones](evidencias/informe/anexo-f/REPRODUCCION.md).

Se han reportado cierres del editor de conversión de Visual Studio 2026, incluso en interacción manual según las instrucciones de cierre. En esta ejecución no se reprodujo manualmente. DTExec x64, el mantenimiento mediante las API de SSIS y la lectura de staging están verificados. [Diagnóstico](evidencias/informe/anexo-b/DIAGNOSTICO_EDITOR_REVIEWS.md) · [Resultados de la carga principal](evidencias/informe/anexo-b/principal-carga.txt).
