# SQL Server y Data Mart
Base local BI_OLIST, esquemas stg/dw/audit. Castilla implementará DDL repetible después; aún no existe. Staging conserva fuente y auditoría/rechazos. DW usa claves y restricciones del contrato, DECIMAL para dinero, DATETIME2/DATE para fechas y miembro desconocido. Pagos/reviews se agregan al grano pedido. Conexiones locales parametrizadas. SQL Server Developer es académico/no productivo cuando se requiere SSAS; Express no lo incluye, SSAS se instala aparte.
# BI_OLIST: creación y pruebas

Ejecutar desde PowerShell con SQL Server local instalado. La conexión actual fue comprobada en Windows contra SQL Server 2025 Express (`SQLEXPRESS`), con autenticación integrada. Sustituye instancia/auth por parámetros locales.

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\00_crear_base.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\01_auditoria.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\02_staging.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\03_dimensiones.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\04_hechos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\05_controles.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -i database\06_pruebas.sql
```

`-C` se documenta porque el certificado del motor local no se encontraba en la cadena de confianza del equipo; limita su uso al motor local administrado. No usar para conexiones remotas sin validar TLS. `03_dimensiones.sql` configura las opciones requeridas para crear constraints/índices.

Los scripts 00–05 crean únicamente objetos ausentes y datos de referencia desconocidos; no eliminan tablas ni reinicializan datos. `06_pruebas.sql` exige las tablas vacías de pruebas y ejecuta inserts sintéticos dentro de una transacción revertida. Los valores `TEST-*` no son datos de negocio. Ejecutar 00–05 de nuevo valida reejecución. La carga/limpieza por lote de staging y el upsert DW son responsabilidad de SSIS, no están implementados por estos scripts.

## Objetos

- `audit.Batch`, `audit.Reject` y vista `audit.vw_BatchStatus`: estados `PENDING`, `RUNNING`, `COMPLETE`, `FAILED`; conteos, hash, fecha/contexto y rechazos trazables.
- Nueve tablas `stg` reflejan las columnas CSV y añaden `batch_id`, `source_row_number`, `row_id`, `loaded_at`. No aplican unicidad de clave natural para conservar duplicados y multiplicidades.
- `dw.DimFecha`, `DimCliente`, `DimProducto`, `DimVendedor`, `DimGeografiaCliente`, `DimGeografiaVendedor`, cada una con miembro técnico desconocido `-1`.
- `dw.FactPedidos` (único `order_id`) y `dw.FactDetallePedido` (único `(order_id, order_item_id)`); claves foráneas apuntan a dimensiones. No hay FK directa entre hechos.

Ver `05_controles.sql` para duplicados de staging, grano de hechos y conciliación. Su salida vacía significa que el staging está vacío o que no hay duplicados; no acredita carga de archivos.
