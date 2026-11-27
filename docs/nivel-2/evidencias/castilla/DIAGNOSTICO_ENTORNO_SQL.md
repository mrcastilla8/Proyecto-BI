# Diagnóstico de Entorno y Base de Datos `BI_OLIST` — Castilla

**Fecha:** 2026-11-27  
**HEAD inicial:** `e15fede1928518f096cd8e2b0edcd456af9cf41c`  
**Rama:** `castilla/nivel-2-integracion`

## 1. Entorno Windows y herramientas detectadas

| Componente | Estado observado | Versión / Detalle |
|---|---|---|
| Sistema operativo | Disponible | Microsoft Windows 11 Home Single Language (`10.0.26300`, 64 bits) |
| SQL Server (Motor) | En ejecución | `MSSQL$SQLEXPRESS` (`MSSQL17.SQLEXPRESS`, SQL Server 2025 64-bit `17.0.1000.7`) |
| SQL Server Analysis Services | En ejecución | `MSOLAP$SSASBI` (`MSAS17.SSASBI`, SSAS `17.0.25.218`) |
| SQL Server Integration Services | Instalado | SSIS 2025 (`17.0.1000.7`) + `DTExec.exe` x64 `17.0.1000.7` + SSIS Projects `17.0.1016.0` |
| Visual Studio | Instalado | Visual Studio Community 2026 (`18.10.3`) |
| `sqlcmd` | Disponible | `18.x` (Client SDK ODBC 180) |
| SSMS | Instalado | SQL Server Management Studio 22 (`22.10.2`) |
| Power BI Desktop | Instalado | `2.159.1231.0` (x64) |
| Microsoft Report Builder | **Instalado** | `15.1.30001.02` (`C:\Program Files\Microsoft Report Builder\MSReportBuilder.exe`) |
| SSRS (Reporting Services) | **Instalado y en ejecución** | SSRS 2022 Developer (`SQLServerReportingServices` `Running / Automatic`), catálogo `ReportServer` / `ReportServerTempDB` `ONLINE` en `.\SQLEXPRESS`, portal `http://localhost/Reports` (`HTTP 200`) y servicio SOAP `http://<equipo>/ReportServer` (`HTTP 200`) |
| CSV auténticos Olist | Encontrados localmente | 9 archivos en carpeta local externa (`olist_*.csv` y `product_category_name_translation.csv`) |

## 2. Auditoría inicial de `BI_OLIST` en `.\SQLEXPRESS` (Caso C)

Al inicio de la sesión, `BI_OLIST` existía `ONLINE` en `.\SQLEXPRESS` únicamente con el esquema y los miembros desconocidos (`-1`):

- `stg.*` (9 tablas): `0` filas en todas las tablas.
- `audit.Batch` y `audit.Reject`: `0` filas.
- `dw.DimCliente`, `dw.DimFecha`, `dw.DimGeografiaCliente`, `dw.DimGeografiaVendedor`, `dw.DimProducto`, `dw.DimVendedor`: `1` fila cada una (miembro `-1`).
- `dw.FactPedidos` y `dw.FactDetallePedido`: `0` filas.
- En `.\SSASBI`, inicialmente solo existía `BI_Compras_Tabular` (`BI_OLIST_Tabular` no estaba desplegado).

## 3. Acciones de recuperación y carga ejecutadas (pipeline SSIS aprobado)

1. **Ingesta (`CSV → staging`):** Se compiló una copia aislada (fuera del repositorio) de `ssis/ingesta/ETL_Olist_Ingesta` con Visual Studio 2026 (`0` errores) y se ejecutó `ETL_Master.dtsx` mediante `DTExec.exe` x64 (`17.0.1000.7`) hacia `.\SQLEXPRESS` (`BI_OLIST`).
   - Durante `OrderReviews`, SQL Server Express registró espera `RESOURCE_SEMAPHORE` (`process_physical_memory_low = 1`); se ajustó `min server memory (MB) = 512` en la instancia local y se reanudó la ejecución idempotente, completando los 9 lotes (`batch_id` `60` a `68`) con estado `COMPLETE`, `1.550.922` filas aceptadas y `0` rechazadas.
2. **Transformación (`staging → dw`):** Se instaló `dw.usp_CargarOlist` ejecutando `ssis/transformaciones/sql/cargar.sql`, se compiló una copia aislada de `ssis/transformaciones/ETL_Olist_Transformacion` y se ejecutó `ETL_Transformar.dtsx` (`DTExec` exit `0`, `39.328 s`), registrando `batch_id = 69` (`DW.Transformacion`, `COMPLETE`, `1.550.922` filas).
3. **Conciliación DW:** Se ejecutó `ssis/transformaciones/sql/conciliar.sql` (`exit 0`):
   - `dw.FactPedidos`: `99.441` filas, pagos `16.008.872,1200`, pedidos con reseña `98.673`, calificación media `4,086793`.
   - `dw.FactDetallePedido`: `112.650` filas, precio `13.591.643,7000`, flete `2.251.909,5400`.
4. **Despliegue y validación SSAS Tabular:** Se otorgó `db_datareader` a la cuenta de servicio local de `SSASBI` en `BI_OLIST` y se ejecutaron `ssas/validacion/Publicar-Modelo.ps1` y `ssas/validacion/Comparar-Metricas.ps1` contra `.\SSASBI`, logrando `PASS` en los 7 escenarios (`38` valores no vacíos y coincidencia de vacíos).

## 4. Estado actual de entorno y bloqueos objetivos restantes

- **Power BI Desktop (`2.159.1231.0`):** `P01` y `P08` fueron abiertos y verificados en vivo (`Conexión dinámica: conectada` a `BI_OLIST_Tabular` en `.\SSASBI`), guardando `powerbi/entregas/castilla/OLIST360_Castilla.pbix` y las capturas auténticas en `docs/nivel-2/evidencias/castilla/capturas/`.
- **Publicación y enlaces en entorno demo final:** SSRS 2022 y Report Builder ya están operativos y probados localmente en este equipo (incluyendo las exportaciones PDF/XLSX de `R01` y `R10`); en `OLIST360_Castilla.pbip` se conservan los placeholders `{{SSRS_WEB_SERVICE_URL}}` y `{{SSRS_WEB_PORTAL_URL}}` para no fijar el nombre del equipo local en Git, quedando pendiente su sustitución por la URL real del entorno de demostración.
