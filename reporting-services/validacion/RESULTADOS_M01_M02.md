# Resultados M01–M05 — ejecución local

- **Fecha:** 2026-11-26
- **Rama:** `poma/nivel-2-reporting`
- **HEAD observado durante las consultas:** `5609b92`; los RDL de M03–M05 todavía estaban en el árbol de trabajo local.
- **Entorno:** Windows 11 Home 25H2, SQL Server 2025 Developer `17.0.1000.7`.
- **Alcance:** SSRS, plantilla OLIST 360°, R07 y R08. SSAS y PBIX quedan fuera de esta corrección.

## Estado real de la infraestructura

| Componente | Resultado observado | Estado |
|---|---|---|
| SQL Server | `MSSQLSERVER` activo; base `BI_OLIST` accesible en `localhost` | PASS |
| SSRS Native Mode | WMI: SQL Server Reporting Services Developer `16.0.1122.6`; servicio `SQLServerReportingServices` en ejecución e inicio automático | PASS |
| Catálogo SSRS | `ReportServer` y `ReportServerTempDB` no aparecen en `sys.databases` | BLOCKED |
| URLs locales | `http://localhost/ReportServer` y `/Reports` rechazan la conexión en el puerto 80 | BLOCKED |
| Report Builder | MSI oficial `15.1.30001.02`, firma `Valid` de Microsoft y SHA-256 `77EFD0D45ED03DB04501A1561A431C60BC69DEFA8F9A730EBFD5916EC6BF2469`. La instalación silenciosa terminó con MSI 1603 / error 1925 por falta de elevación. Se abrió el instalador elevado para completar el paso con Windows; aún no se ha confirmado que finalice | PENDIENTE |
| Origen compartido `BI_OLIST_DW` | No puede crearse ni probarse mientras el catálogo y el portal no estén configurados | PENDIENTE |

La consola de configuración de SSRS se abrió elevada. Windows no permite que el ayudante de escritorio controle esa ventana; requiere completar manualmente la creación del catálogo y las URLs. No se publicaron informes ni se generaron capturas o exportaciones ficticias.

## Consultas reales y validación de M03–M05

Las consultas fueron de solo lectura y se ejecutaron contra `localhost/BI_OLIST` con los SQL versionados.

| Prueba | Resultado observado |
|---|---|
| PRE-G0 humo SQL | 99.441 pedidos; 112.650 líneas; ejecución `2026-11-26 21:14:17 UTC` |
| R07, rango completo `2016-09-04`–`2018-10-17`, todos los estados | 162 filas agregadas; total 99.441 pedidos, 99.440 con pago, 1 sin pago; suma observada `16.008.872,1200` |
| R07, estado desconocido/NULL | 0 filas porque `order_status` tiene 0 valores NULL en los datos actuales |
| R08, pedido existente con varias líneas | 1 fila de cabecera; 2 líneas; pago agregado presente |
| R08, identificador inexistente | 0 filas de cabecera y 0 de detalle |
| RDL locales de humo, R07 y R08 | XML parseable; datasets enlazados al origen compartido; consultas coinciden con sus SQL versionados; R07/R08 tienen parámetros declarados y mensaje sin resultados |

Estos resultados validan las consultas locales. No demuestran todavía que SSRS renderice los RDL: faltan catálogo, portal, origen compartido y ejecución desde el portal.

## Validaciones ejecutadas

- `python scripts/validar_base.py`: **PASS** — documentación, contratos, fixtures sintéticas y controles base.
- `reporting-services/scripts/Validar-Scripts.ps1`: **PASS** — PowerShell `7.6.9`, siete archivos sin errores de parseo.
- `reporting-services/scripts/Validar-RDLHumo.ps1`: **PASS** — RDL-01 a RDL-06 del informe de humo.
- Comparación local de datasets R07/R08 con `datasets/*.sql`: **PASS** — cinco consultas coinciden exactamente después de normalizar espacios.
- `git diff --check`: **PASS** en los cambios rastreados.
- Instalación silenciosa de Report Builder: **FAIL** — error MSI 1925; se necesita elevación de Windows.
- Catálogo, portal, publicación del humo, ejecución SSRS, exportación PDF/XLSX y apertura de ambos archivos: **NOT RUN**; el portal aún no responde.

## Pendiente para obtener evidencia de exposición

1. Completar con elevación local la instalación de Report Builder y la configuración SSRS: catálogo `ReportServer`/`ReportServerTempDB`, servicio, Web Service URL y Web Portal URL.
2. Crear `/OLIST360` y el origen compartido `/OLIST360/DataSources/BI_OLIST_DW`, apuntando a `BI_OLIST` con autenticación Windows local.
3. Publicar y ejecutar `PRE_G0_Humo`; comparar sus conteos con la consulta real documentada arriba.
4. Exportar desde el portal a PDF y Excel, abrir ambos archivos y registrar hashes y capturas redactadas.
5. Validar R07 y R08 renderizados en SSRS. Publicar los diez informes juntos cuando los otros ocho RDL estén disponibles.
6. Actualizar la matriz y el índice de evidencias con el SHA del commit que se pruebe. Mantener el PR #15 en Draft.

No se modificaron `database/`, `contracts/`, `ssis/`, SSAS, DAX ni el PBIX maestro. No se crearon cuentas de lectura ni roles especiales.
