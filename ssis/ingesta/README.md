# SSIS: CSV a staging

Responsable: Gabriel Poma (`@GabrielPGu`). Rama: `poma/ssis-ingesta`. Alcance: cargar las nueve fuentes Olist en `BI_OLIST.stg`, con trazabilidad por lote, rechazos y reejecución. Las transformaciones hacia `dw` pertenecen a `ssis/transformaciones`.

## Estado actual

La configuración SQL local está preparada y se verificó que las nueve tablas `stg`, `audit.Batch`, `audit.Reject`, `audit.trg_Batch_Transition` y `audit.vw_BatchStatus` existen. El proyecto real está en `ETL_Olist_Ingesta/`: solución `ETL_Olist_Ingesta.slnx`, proyecto `ETL_Olist_Ingesta.dtproj` y paquete `ETL_Orders.dtsx`. Gabriel configuró los parámetros de proyecto `CSV_ROOT`, `SQL_SERVER` y `SQL_DATABASE`. Al 19-11-2026 el paquete no contiene tareas ni variables; no hay administradores de conexión ni flujos de datos. Las nueve ingestas, auditoría operativa e idempotencia siguen pendientes. No se afirma que haya cargas de datos.

Visual Studio Community 2026 (18.10.3) y la extensión Microsoft **SQL Server Integration Services Projects 2022+** (2.2) están instalados; se localizaron su manifiesto y plantilla de proyecto. También están disponibles MSBuild 18.10.1.42706 y `DTExec` 17.0. SQL Server local es 17.0.1000.7, Developer Edition de 64 bits; SSMS 22.10.2 y SQLCMD con controlador ODBC 17 están instalados. La autenticación integrada a `localhost` funciona.

Visual Studio Community 2026 y SSIS Projects 2022+ están disponibles. La compilación se confirmó desde la interfaz de Visual Studio después de guardar el proyecto: 1 proyecto, 0 errores, 0 advertencias; se generó `bin/Development/ETL_Olist_Ingesta.ispac`. Esta compilación solo verifica el paquete vacío y no es una prueba de ejecución ni de carga. La compilación de `devenv.com` desde terminal había devuelto un error de licencia; no reproduce el resultado de la interfaz y no es motivo para reparar Visual Studio.

## Requisitos y configuración portable

- Windows, Visual Studio Community y la extensión SSIS Projects.
- SQL Server con `BI_OLIST` creada mediante los scripts aprobados de `database/`.
- Los nueve CSV auténticos, obtenidos y autorizados por el usuario, disponibles bajo una carpeta local parametrizada como `CSV_ROOT`.
- Autenticación integrada de Windows recomendada. No guardar contraseñas, rutas personales ni nombre del equipo en Git.

Los tres parámetros existentes son String, opcionales y no confidenciales. `SQL_SERVER=localhost` y `SQL_DATABASE=BI_OLIST` son valores portables para este entorno local. El valor personal de `CSV_ROOT` no debe guardarse como predeterminado en Git; el valor publicado se dejó vacío para exigir una configuración local al ejecutar. Aún no existe una conexión de archivo plano ni una expresión que consuma `CSV_ROOT`; tampoco están declaradas conexiones SQL vinculadas a los parámetros.

## Fuentes y destino

| Archivo | Tabla | Filas de origen verificadas |
|---|---|---:|
| `olist_orders_dataset.csv` | `stg.Orders` | 99 441 |
| `olist_order_items_dataset.csv` | `stg.OrderItems` | 112 650 |
| `olist_order_payments_dataset.csv` | `stg.OrderPayments` | 103 886 |
| `olist_order_reviews_dataset.csv` | `stg.OrderReviews` | 99 224 |
| `olist_customers_dataset.csv` | `stg.Customers` | 99 441 |
| `olist_sellers_dataset.csv` | `stg.Sellers` | 3 095 |
| `olist_products_dataset.csv` | `stg.Products` | 32 951 |
| `olist_geolocation_dataset.csv` | `stg.Geolocation` | 1 000 163 |
| `product_category_name_translation.csv` | `stg.ProductCategoryTranslation` | 71 |

La suma observada es 1 550 922 registros sin cabeceras. La validación se realizó con el perfilador estándar ya existente `scripts/perfilar_dataset.py`; lee y resume datos, no carga ni transforma filas. Los nueve encabezados coincidieron con el contrato, el parser CSV estricto no detectó filas irregulares y las fechas y números reconocidos por el perfilador se pudieron interpretar. No se encontraron valores vacíos en campos contractualmente requeridos ni longitudes de texto por encima de la columna de destino. Hay campos opcionales vacíos: Orders (approved 160, carrier 1 783, delivered customer 2 965), Reviews (comment title 87 656, comment message 58 247) y Products (category/name-length/description-length/photos 610 cada uno, cuatro dimensiones 2 cada una). Deben conservarse como nulos.

Las reviews contienen saltos de línea dentro de comentarios en 3 852 registros, comas en 14 501 y comillas en 174; además, 23 646 filas de comentario incluyen caracteres no ASCII. El componente Flat File debe procesar el calificador `"` y los campos multilínea. La fuente contiene 261 831 filas exactas duplicadas adicionales en Geolocation y 814 repeticiones de `review_id`; se preservan mediante ordinal físico y no se deduplican.

Escalas máximas observadas: `price`, `freight_value` y `payment_value` 2; dimensiones/peso de Products 0; latitud 20 y longitud 16. Las fechas observadas tienen 19 caracteres (`YYYY-MM-DD HH:MM:SS`). La ejecución de perfil reproduce la inspección con `python scripts/perfilar_dataset.py "$env:CSV_ROOT"` después de asignar la carpeta local a `CSV_ROOT`.

Las tablas conservan columnas de origen y agregan `batch_id`, `source_row_number` y `loaded_at`. La clave técnica única es `(batch_id, source_row_number)`; las claves de negocio no se hacen únicas en staging, porque se preservan duplicados válidos de origen. Deben respetarse los nombres contractuales, incluidos `product_name_lenght` y `product_description_lenght`, los códigos postales como texto, `DECIMAL` para importes/medidas y `DATETIME2(0)` para fechas.

Se debe usar Flat File Connection Manager/Source, conversiones y salidas de error SSIS, OLE DB Connection Manager/Destination, parámetros y control de flujo. Python, `BULK INSERT` o scripts externos no sustituyen el ETL SSIS.

## Formato de archivo

Los nueve CSV se encontraron en la carpeta local indicada por Gabriel; la subcarpeta `csv` mencionada inicialmente no existe. Los encabezados reales coinciden en nombre y orden con los nueve mapeos anteriores. Son UTF-8; ocho no llevan BOM y `product_category_name_translation.csv` sí lleva BOM UTF-8. Un parser CSV de Windows que respeta comillas procesó todos los registros y encontró cero filas con anchura distinta de su encabezado. Recuentos observados (sin cabecera): orders 99 441; order items 112 650; payments 103 886; reviews 99 224; customers 99 441; sellers 3 095; products 32 951; geolocation 1 000 163; traducciones 71; total 1 550 922. Esto confirma delimitación y anchura, pero todavía no constituye validación de conversiones SSIS, longitudes de destino o carga SQL.

## Auditoría, reejecución y recuperación

Usar `audit.Batch`, `audit.Reject` y `audit.vw_BatchStatus`, respetando `audit.trg_Batch_Transition` y el ciclo descrito en [database/README.md](../../database/README.md):

1. Calcular SHA-256 y buscar lote por fuente, hash y versión de contrato (`1.0.0`). Si hay uno `COMPLETE`, omitir la carga.
2. Si el contenido o contrato cambió, crear un lote `PENDING`. Para `PENDING`, `RUNNING` incompleto o `FAILED`, cambiar/recuperar a `RUNNING` según la transición permitida, limpiar solo filas/rechazos del mismo lote y recargar dentro de una transacción coherente.
3. Mantener `rows_read`, `rows_accepted` y `rows_rejected` conciliables. Cerrar `COMPLETE` solo si leídas = aceptadas + rechazadas. En fallo, revertir la carga y registrar `FAILED` en una transacción de auditoría separada.
4. Registrar archivo, origen, hash, versión, timestamps, duración en `execution_context` si corresponde, error sin datos personales y cada rechazo con fila, campo, código y razón cuando esos datos puedan determinarse.

Esta política todavía no está implementada en paquetes SSIS; no se debe marcar un lote como completo hasta probarla en SQL Server.

## Preparación local realizada

Se detectó la instancia predeterminada `localhost`; no se usó `SQLEXPRESS`. La conexión integrada identificó el servidor local y el usuario Windows como `sysadmin`. `BI_OLIST` no existía al iniciar la tarea. Se ejecutaron, sin modificar sus definiciones, los scripts aprobados:

```powershell
sqlcmd -S localhost -E -C -b -i database\00_crear_base.sql
sqlcmd -S localhost -E -C -b -i database\01_auditoria.sql
sqlcmd -S localhost -E -C -b -i database\02_staging.sql
sqlcmd -S localhost -E -C -b -i database\03_dimensiones.sql
sqlcmd -S localhost -E -C -b -i database\04_hechos.sql
sqlcmd -S localhost -E -C -b -i database\05_controles.sql
sqlcmd -S localhost -E -C -b -i database\06_pruebas.sql
```

Resultado observado: base `BI_OLIST`, nueve tablas `stg`, las tablas `audit.Batch`/`audit.Reject`, el trigger `audit.trg_Batch_Transition` y la vista `audit.vw_BatchStatus`. Las tablas de ingesta y auditoría quedaron vacías. El script 06 devolvió `PASS` y revirtió sus filas `TEST-*`; no es una prueba de los paquetes SSIS.

Consulta de comprobación:

```sql
SELECT s.name AS esquema, t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id=t.schema_id
LEFT JOIN sys.partitions AS p ON p.object_id=t.object_id AND p.index_id IN (0,1)
WHERE s.name IN ('stg','audit')
GROUP BY s.name,t.name
ORDER BY s.name,t.name;
```

## Pruebas y estado de evidencia

Ejecutado en Windows:

- `python scripts/validar_base.py` — PASS.
- `python -m unittest discover -s scripts -p "test_*.py" -v` — PASS, 14 pruebas.
- `sqlcmd -S localhost -E -C -b -i database\06_pruebas.sql` — PASS; pruebas SQL positivas/negativas y datos sintéticos revertidos.
- SQLCMD integrado a `localhost/BI_OLIST` — PASS para lectura de metadatos; se confirmaron 9 tablas `stg` y las tablas `audit.Batch` y `audit.Reject`, todas sin filas.

Pendiente: reparar la licencia de Visual Studio; implementar y compilar los nueve flujos SSIS; pruebas SSIS con fixtures (nulos, inválidos, duplicados, reintento y recuperación); verificar conversiones, longitudes y formatos; ejecutar cargas e idempotencia con originales; conciliar filas/rechazos con auditoría. No hay capturas auténticas de ejecución SSIS todavía. Los resultados de metadatos SQL no son evidencia de ETL.

Cuando existan los paquetes, desde Visual Studio seleccionar el parámetro de entorno con `CSV_ROOT` y la conexión SQL, ejecutar el paquete maestro (o los nueve paquetes si se organizan separados), y conservar los mensajes de ejecución y esta consulta de auditoría:

```sql
SELECT batch_id,source_name,source_file,status,started_at,finished_at,
       rows_read,rows_accepted,rows_rejected,error_message
FROM audit.vw_BatchStatus
ORDER BY batch_id;

SELECT batch_id,source_name,source_row_number,field_name,reason_code,reason
FROM audit.Reject
ORDER BY batch_id,source_name,source_row_number;
```

No se han incluido CSV originales, credenciales ni filas reales en el repositorio.
