# Índice de evidencias SSRS — M01–M07 (corte 2026-11-27)

La infraestructura M01–M02 y la plantilla M03 ya estaban configuradas. Esta actualización registra la publicación y ejecución local de seis informes de diez: R02, R04, R06, R07, R08 y R09. Los resultados, parámetros, conteos, limitaciones, hashes y comandos están en [`validacion/RESULTADOS_M06_M07.md`](../validacion/RESULTADOS_M06_M07.md); los casos observados están en [`validacion/matriz.csv`](../validacion/matriz.csv). SHA fuente probado: `e15fede1928518f096cd8e2b0edcd456af9cf41c`.

| ID | Evidencia | Resultado observado | Estado |
|---|---|---|---|
| EVD-SSRS-01 | Versión SSRS, servicio y Report Builder | SSRS Developer Native Mode `16.0.1122.6`; servicio `SQLServerReportingServices` Running/Auto; Report Builder `15.1.30001.02` | PASS |
| EVD-SSRS-02 | Catálogo SSRS | `ReportServer` y `ReportServerTempDB` ONLINE en SQL Server local | PASS |
| EVD-SSRS-03 | Portal y Web Service | HTTP 200 en `http://localhost/Reports` y `http://localhost/ReportServer`; WSDL HTTP 200, sin redirecciones | PASS |
| EVD-SSRS-04 | Roles avanzados y cuenta de prueba no autorizada | No requeridos por el alcance académico simplificado vigente | NOT_IN_SCOPE |
| EVD-SSRS-05 | Origen compartido `BI_OLIST_DW` | Publicado en `/OLIST360/DataSources/BI_OLIST_DW`, autenticación integrada, ejecuciones reales contra `BI_OLIST` | PASS |
| EVD-SSRS-06 | Árbol de informes publicados | R02, R04, R06, R07, R08 y R09 disponibles bajo `/OLIST360`; R01, R03, R05 y R10 pendientes | PARCIAL (6/10) |
| EVD-SSRS-07 | Matriz de ejecución | Seis RDL ejecutados localmente con parámetros documentados en la matriz; cuatro informes pendientes de integración | PARCIAL (6/10) |
| EVD-SSRS-08 | Exportaciones verificables | Seis PDF y seis XLSX generados y abiertos/revisados; la meta contractual de diez pares queda pendiente | PARCIAL (6/10) |
| M03-01 | Plantilla | XSD SSRS 2016 validado y plantilla publicada | PASS |
| M04-R07 | R07 Importes Pagados | Consulta y exportaciones reales; 162 agregados, 99.441 pedidos, 99.440 con pago y 1 sin pago observado | PASS |
| M05-R08 | R08 Ficha de Pedido | Consulta y exportaciones reales para pedido existente y control inexistente; datos de pedido solo locales | PASS |
| VIS-01 | Captura de PRE_G0_Humo en portal | [`ssrs-humo-portal.png`](ssrs-humo-portal.png), captura local anterior, sin identidad del usuario | PASS |
| VIS-02 | Apertura de exportaciones del humo | La apertura del par PRE_G0_Humo en aplicaciones sigue pendiente; no se marca el caso G0 como cerrado | PENDIENTE |
| VIS-03 | Verificación visual de los seis informes | Se inspeccionaron las seis vistas de PDF y los seis libros en Excel. Se versionan cinco vistas agregadas; la vista de R08 permanece local por contener datos de pedido | PASS |
| PRE-G0-08 | Power BI Live a SSAS | SSAS y PBIX fuera del alcance de esta entrega | NOT_IN_SCOPE |

## Material disponible

- Las vistas de página de los PDF SSRS de R02, R04, R06, R07 y R09 están en [`renderizados-2026-11-27/`](renderizados-2026-11-27/). Son representaciones rasterizadas de exportaciones reales, no capturas del navegador del portal.
- La vista PDF de R08 y los seis pares de exportación completos permanecen en `validacion/salidas/`, ignorado por Git. R08 contiene datos de un pedido individual y no se incluye en Git.
- `R09` ejecuta y muestra las métricas; el gráfico “Ventas vs. máximo” se representa como barras verticales repetidas en el PDF y necesita ajuste visual.
- La captura `ssrs-humo-portal.png` tiene SHA-256 `B7932E6DC7E43CD3DD31FFB1B4561BEC70E09DBF65DE844A24033F5F1F735540`. El informe temporal de humo sigue publicado en `/OLIST360/Pruebas/PRE_G0_Humo` para revisión local.
