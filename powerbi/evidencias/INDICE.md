# Índice de evidencias de Power BI

Capturas reales del 20-11-2026, hora de Lima (UTC−05:00). La hora es la de creación del archivo de imagen. Todo se ejecutó en un único equipo Windows 11 con instancias locales por defecto (`localhost`), sin exponer servicios a la red.

## Entorno

| Componente | Versión observada |
|---|---|
| SQL Server | 2025 (RTM) 17.0.1000.7, Standard Developer Edition (64-bit) |
| SSAS | Tabular 17.0.25.218, edición `StandardDeveloper64` |
| Visual Studio | Community 2026 con SSIS y Analysis Services Projects |
| SSMS | 22 |
| Power BI Desktop | 2.159.1231.0 (Microsoft Store) |

## Reproducción de la cadena de datos

Antes de construir el informe se reprodujo localmente la cadena completa con el dataset auténtico de Olist (Kaggle, versión 2). Los CSV quedaron fuera del repositorio.

| ID | Imagen | Hora | Herramienta | Resultado |
|---|---|---|---|---|
| ENT-01 | [ENT-01-lotes-ingesta.png](entorno/ENT-01-lotes-ingesta.png) | 13:08:41 | SSMS | Ingesta SSIS ejecutada desde el depurador de Visual Studio. Lotes 7–15 `COMPLETE`, 1.550.922 filas aceptadas y 0 rechazadas. |
| ENT-02 | [ENT-02-conciliacion-dw.png](entorno/ENT-02-conciliacion-dw.png) | 13:10:35 | SSMS | `ssis/transformaciones/sql/conciliar.sql`: lote 16 `COMPLETE`, 99.441 pedidos, 112.650 líneas, calificación media 4,086793 y huellas SHA-256 de las ocho tablas del DW. |
| ENT-03 | [ENT-03-permiso-ssas.png](entorno/ENT-03-permiso-ssas.png) | 13:11:23 | SSMS | La cuenta de servicio `NT Service\MSSQLServerOLAPService` tiene `SELECT` sobre el esquema `dw`. |
| ENT-04 | [ENT-04-catalogo-tabular.png](entorno/ENT-04-catalogo-tabular.png) | 13:20:45 | SSMS (Analysis Services) | Catálogo `BI_OLIST_Tabular` desplegado con sus ocho tablas. |
| ENT-05 | [ENT-05-cotejo-sql-dax.png](entorno/ENT-05-cotejo-sql-dax.png) | 13:24:05 | Windows PowerShell 5.1 | `ssas/validacion/Comparar-Metricas.ps1`: PASS en los siete escenarios, 38 valores no vacíos y vacíos coincidentes. |

## Informe

| ID | Imagen | Hora | Página | Resultado |
|---|---|---|---|---|
| REP-01 | [REP-01-conexion-live.png](reporte/REP-01-conexion-live.png) | 13:34:44 | Panel Datos | *Conexión dinámica: conectada*. Tablas, jerarquías y carpetas de medidas del modelo SSAS, sin vistas Tabla ni Modelo. |
| REP-02 | [REP-02-resumen-ejecutivo.png](reporte/REP-02-resumen-ejecutivo.png) | 14:30:05 | Resumen ejecutivo | Las ocho tarjetas coinciden con el escenario `total` de ENT-05. |
| REP-03 | [REP-03-logistica.png](reporte/REP-03-logistica.png) | 15:03:21 | Logística y cumplimiento | 93,23 % a tiempo y 12,56 días. Los pedidos por estado suman 99.441. La tabla de estados del cliente muestra AL (78,59 %) como el de peor cumplimiento. |
| REP-04 | [REP-04-productos-vendedores.png](reporte/REP-04-productos-vendedores.png) | 15:03:33 | Productos y vendedores | El total de la tabla por vendedor da R$ 13.221.498,11 en ventas, 96.478 pedidos, ticket de R$ 137,04 y flete de R$ 2.198.275,64. |
| REP-05 | [REP-05-satisfaccion-geografia.png](reporte/REP-05-satisfaccion-geografia.png) | 15:03:44 | Satisfacción y geografía | Calificación de 4,09 y SP con 4,17 y 95,51 %, igual que el escenario `cliente_sp` de ENT-05. La dispersión muestra que los estados con menor puntualidad tienen menor calificación. |

## Incidencias y limitaciones del entorno

- **Las bibliotecas TOM/ADOMD de la extensión SSAS de Visual Studio 2026 (17.0.39) rechazan la edición `StandardDeveloper64`.** El error es *"The current edition 'StandardDeveloper64' of the target SQL Server Analysis Services instance is not supported by the client"*. Los scripts `Publicar-Modelo.ps1` y `Comparar-Metricas.ps1` se ejecutaron sin modificar en Windows PowerShell 5.1 con las bibliotecas de SSMS 22 (17.0.65). Para ello hizo falta resolver la dependencia `Microsoft.Identity.Client` desde la instalación de SSMS.
- **La ingesta se ejecutó desde el depurador de Visual Studio**, según la entrega de ingesta. Los parámetros locales de los proyectos SSIS se revirtieron después y no se versionan.
- **El informe se editó también como proyecto PBIP local**, ignorado por Git, y se guardó de nuevo como `BI_OLIST.pbix`. El PBIX contiene cuatro páginas, 47 visuales y la conexión `analysisServicesDatabaseLive`, sin modelo de datos importado.
- **No se probaron el servicio Power BI ni una puerta de enlace.** El alcance es Power BI Desktop en local.
