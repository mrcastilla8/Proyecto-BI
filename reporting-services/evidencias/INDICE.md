# Índice de evidencias SSRS — M01–M08 (corte 2026-11-27)

El corte actual registra los diez informes publicados, ejecutados y exportados a PDF/XLSX en el SSRS local. Las salidas completas permanecen en `validacion/salidas/`, ignorado por Git; el manifiesto y los resultados redaccionados están versionados. El detalle operativo está en [`validacion/CIERRE_POMA.md`](../validacion/CIERRE_POMA.md), [`validacion/RESULTADOS_M06_M07.md`](../validacion/RESULTADOS_M06_M07.md), [`validacion/RESULTADOS_M08.md`](../validacion/RESULTADOS_M08.md), [`validacion/HANDOFF_INTEGRACION.md`](../validacion/HANDOFF_INTEGRACION.md) y [`validacion/matriz.csv`](../validacion/matriz.csv).

| ID | Evidencia | Resultado observado | Estado |
|---|---|---|---|
| EVD-SSRS-01 | SSRS, servicio y Report Builder | SSRS Developer `16.0.9819.33617` detectado; servicio `Running`/Auto; Report Builder `15.1.30001.02` | PASS |
| EVD-SSRS-02 | Catálogo SSRS | `ReportServer` y `ReportServerTempDB` ONLINE | PASS |
| EVD-SSRS-03 | Portal y Web Service | `http://localhost/Reports` y `http://localhost/ReportServer` HTTP 200; SOAP `ReportService2010` HTTP 200 | PASS |
| EVD-SSRS-04 | Autenticación/roles | Sesión Windows integrada usada; cuenta de rechazo y permiso `Browser` de solo lectura no probados | PARCIAL |
| EVD-SSRS-05 | Origen compartido `BI_OLIST_DW` | `/OLIST360/DataSources/BI_OLIST_DW`, autenticación integrada; ejecuciones reales contra `BI_OLIST`; identidad dedicada `SELECT` no comprobada | PARCIAL |
| EVD-SSRS-06 | Árbol de informes publicados | R01–R10 encontrados en las rutas definitivas bajo `/OLIST360`; el humo temporal ya fue retirado | PASS (10/10) |
| EVD-SSRS-07 | Matriz de ejecución | R01–R10 ejecutados con parámetros documentados y resultados reales | PASS (10/10) |
| EVD-SSRS-08 | Exportaciones PDF/XLSX | Diez pares exportados, formatos comprobados y libros abiertos en Excel; R09 tiene un defecto gráfico anotado | PASS exportación; PARCIAL visual |
| M03-01 | Plantilla RDL | XSD SSRS 2016 validado; plantilla disponible para reutilizar | PASS |
| M04-R07 | R07 Importes pagados | 162 agregados; 99.441 pedidos; un pedido sin pago observado; `NULL` de suma se mantiene distinto de cero | PASS |
| M05-R08 | R08 Ficha de pedido | Pedido con dos líneas, control inexistente y pedido sin líneas; identificador y archivos solo locales | PASS |
| PRE-G0-06 | Informe de humo | PDF mostró 99.441 pedidos y 112.650 líneas; el elemento temporal se retiró después | PASS |
| PRE-G0-07 | Exportación del humo | PDF una página, XLSX Open XML y apertura en Excel verificados | PASS |
| PRE-G0-08 | Power BI Live a SSAS | No se encontró servicio SSAS; no se abrió ni modificó el PBIX maestro | BLOCKED |
| VIS-01 | Captura de humo en portal | [`ssrs-humo-portal.png`](ssrs-humo-portal.png), conteos agregados visibles y sin datos de pedidos | PASS (captura histórica) |
| VIS-02 | Apertura de exportaciones del humo | PDF renderizado sin página vacía y XLSX abierto en Excel; ambos con los conteos agregados | PASS |
| VIS-03 | Inspección de las exportaciones de informes | 62 páginas PDF renderizadas y revisadas; libros XLSX abiertos; el gráfico de R09 queda como defecto visual | PARCIAL |
| INT-01-POMA | Apoyo a P08 | Diez rutas de portal/servicio publicadas y manifiestadas; los botones del PBIX no se probaron | BLOCKED (lado PBI) |
| INT-02 | Navegación entre RDL | R01→R02, R01→R09, R02→R04, R05→R08 y R09→R05/R06 abren sus destinos; se preservan los parámetros acordados | PASS |
| INT-03-POMA | Reproducción en equipo demo | Se documentaron URLs loopback, reproducción y dependencias; SSAS y acceso al PBIX no forman parte de este entorno | BLOCKED (lado PBI) |

## Material disponible

- Las vistas rasterizadas de páginas PDF agregadas R02, R04, R06, R07 y R09 siguen en [`renderizados-2026-11-27/`](renderizados-2026-11-27/). La imagen R09 permite observar el defecto “Ventas vs. máximo”.
- Los diez pares exportados y sus renderizados completos están en `validacion/salidas/cierre-poma-2026-11-27/`, ignorado por Git. R05 contiene identificadores de pedido y R08 detalle transaccional; por eso no se añadieron imágenes de esas páginas al repositorio.
- Los resultados y hashes de exportaciones agregadas están en [`validacion/RESULTADOS_M06_M07.md`](../validacion/RESULTADOS_M06_M07.md). Los hashes del R08 y sus archivos permanecen locales.
- `validacion/manifiesto-publicacion.csv` registra las diez rutas y hashes de RDL. `validacion/manifiesto-urls.csv` registra los accesos locales sin incluir el parámetro `OrderId`.
- El informe temporal `/OLIST360/Pruebas/PRE_G0_Humo` se eliminó por `ReportService2010.DeleteItem`; el origen compartido y el catálogo se conservaron.

La matriz de certificación global del Nivel 2 no se declara cerrada: este índice cubre los controles y el apoyo de Poma, no las pruebas asignadas a los demás responsables.
