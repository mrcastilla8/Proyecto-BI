# SSIS: CSV a staging

Responsable: Gabriel Poma (`@GabrielPGu`). Rama: `poma/ssis-ingesta`. Alcance: cargar las nueve fuentes Olist en `BI_OLIST.stg`, con trazabilidad por lote, rechazos y reejecución. Las transformaciones hacia `dw` pertenecen a `ssis/transformaciones`.

## Estado actual

La configuración SQL local está preparada y se verificó que las nueve tablas `stg` y las tablas `audit.Batch` y `audit.Reject` existen. Aún no existe un proyecto SSIS en esta carpeta: no hay `.sln`, `.dtproj` ni `.dtsx`. No se afirma que haya cargas de datos ni una compilación SSIS.

Visual Studio Community 2026 (18.10.3) y la extensión Microsoft **SQL Server Integration Services Projects 2022+** (2.2) están instalados; se localizaron su manifiesto y plantilla de proyecto. También están disponibles MSBuild 18.10.1.42706 y `DTExec` 17.0. SQL Server local es 17.0.1000.7, Developer Edition de 64 bits; SSMS 22.10.2 y SQLCMD con controlador ODBC 17 están instalados. La autenticación integrada a `localhost` funciona.

En esta sesión, el lanzamiento/inspección automatizada de la interfaz de Visual Studio falló con `unknown or expired node_repl continuation`. Por ese motivo no se creó un proyecto vacío ni se fabricaron paquetes XML. El siguiente paso mínimo es abrir Visual Studio y crear **Integration Services Project** en `ssis/ingesta`; después guardar la solución y el proyecto en esta carpeta. No se necesita instalar la extensión SSIS.

## Requisitos y configuración portable

- Windows, Visual Studio Community y la extensión SSIS Projects.
- SQL Server con `BI_OLIST` creada mediante los scripts aprobados de `database/`.
- Los nueve CSV auténticos, obtenidos y autorizados por el usuario, disponibles bajo una carpeta local `CSV_ROOT`.
- Autenticación integrada de Windows recomendada. No guardar contraseñas, rutas personales ni nombre del equipo en Git.

El proyecto deberá parametrizar `CSV_ROOT`, servidor/instancia SQL y base (`BI_OLIST`). Debe poder cambiarse la carpeta de fixtures a la carpeta de originales desde parámetros de proyecto/entorno, sin editar cada paquete. No se ha creado todavía esa configuración dentro del proyecto.

## Fuentes y destino

| Archivo | Tabla |
|---|---|
| `olist_orders_dataset.csv` | `stg.Orders` |
| `olist_order_items_dataset.csv` | `stg.OrderItems` |
| `olist_order_payments_dataset.csv` | `stg.OrderPayments` |
| `olist_order_reviews_dataset.csv` | `stg.OrderReviews` |
| `olist_customers_dataset.csv` | `stg.Customers` |
| `olist_sellers_dataset.csv` | `stg.Sellers` |
| `olist_products_dataset.csv` | `stg.Products` |
| `olist_geolocation_dataset.csv` | `stg.Geolocation` |
| `product_category_name_translation.csv` | `stg.ProductCategoryTranslation` |

Las tablas conservan columnas de origen y agregan `batch_id`, `source_row_number` y `loaded_at`. La clave técnica única es `(batch_id, source_row_number)`; las claves de negocio no se hacen únicas en staging, porque se preservan duplicados válidos de origen. Deben respetarse los nombres contractuales, incluidos `product_name_lenght` y `product_description_lenght`, los códigos postales como texto, `DECIMAL` para importes/medidas y `DATETIME2(0)` para fechas.

Se debe usar Flat File Connection Manager/Source, conversiones y salidas de error SSIS, OLE DB Connection Manager/Destination, parámetros y control de flujo. Python, `BULK INSERT` o scripts externos no sustituyen el ETL SSIS.

## Formato de archivo

La documentación del perfil anterior describe UTF-8 con BOM opcional, coma, comillas dobles, fechas `YYYY-MM-DD HH:MM:SS` y punto decimal. **Eso todavía no se ha confirmado contra los CSV auténticos de esta máquina.** En las ubicaciones habituales inspeccionadas (raíz del workspace, nivel superior de Desktop y Downloads) no se encontraron los nueve originales; en el repositorio solo están las fixtures sintéticas de `data/fixtures/`. Antes de fijar metadatos de Flat File se debe verificar codificación/BOM, quoting, campos multilínea, encabezados, fechas y números en los archivos reales autorizados.

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

Pendiente: crear y compilar el proyecto SSIS; pruebas SSIS con fixtures (nulos, inválidos, duplicados, reintento y recuperación); localizar/verificar los nueve CSV originales; ejecutar cargas e idempotencia; conciliar filas/rechazos con auditoría. No hay capturas auténticas de ejecución SSIS todavía. Los resultados de metadatos SQL no son evidencia de ETL.

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
