# Índice de evidencias M01–M05

Estado real observado el 2026-11-26 en Windows. El SHA probado para los cuatro RDL y el validador es `feff597f3d066b5f25c82d76eadd29d83c0d9b96`. Resultados, comandos, conteos y hashes de exportación están en `validacion/RESULTADOS_M01_M02.md`; los estados por caso están en `validacion/matriz.csv`.

| ID | Evidencia | Resultado disponible | Estado |
|---|---|---|---|
| EVD-SSRS-01 | Versión SSRS, servicio y Report Builder | SSRS Developer Native Mode `16.0.1122.6`; servicio `SQLServerReportingServices` Running/Auto; Report Builder `15.1.30001.02` | PASS |
| EVD-SSRS-02 | Catálogo SSRS | `ReportServer` y `ReportServerTempDB` ONLINE en SQL Server local | PASS |
| EVD-SSRS-03 | Portal y Web Service | HTTP 200 en `http://localhost/Reports` y `http://localhost/ReportServer`; WSDL HTTP 200, sin redirecciones | PASS |
| EVD-SSRS-04 | Roles avanzados y cuenta de prueba no autorizada | No requeridos por la corrección de alcance académico simplificado | NOT_IN_SCOPE |
| EVD-SSRS-05 | Origen compartido BI_OLIST_DW | Origen SQL publicado en `/OLIST360/DataSources/BI_OLIST_DW`; autenticación integrada y render real contra `BI_OLIST` | PASS |
| EVD-SSRS-06 | Ejecución PRE_G0_Humo | Informe publicado y renderizado con 99.441 pedidos y 112.650 líneas | PASS |
| EVD-SSRS-07 | Exportaciones del humo | PDF y XLSX HTTP 200; firmas/estructura y SHA-256 registrados. Apertura en aplicaciones de escritorio pendiente | PARCIAL |
| EVD-SSRS-08 | Publicación conjunta de diez informes | R07 y R08 publicados; los otros ocho RDL aún no fueron entregados | PENDIENTE |
| M03-01 | Plantilla | XSD SSRS 2016 validado; plantilla publicada | PASS |
| M04-01 | R07 Importes Pagados | Consulta ejecutada y render real; 162 agregados y totales en resultados | PASS |
| M04-02 | Exportaciones R07 | PDF y XLSX HTTP 200, estructuras y hashes registrados; apertura visual pendiente | PARCIAL |
| M05-01 | R08 Ficha de Pedido | Pedido real con dos líneas; informe renderizado y pago agregado presente | PASS |
| M05-02 | Parámetro para pedido inexistente | Consulta real devuelve cero cabeceras y cero líneas | PASS |
| M05-03 | Exportaciones R08 | PDF y XLSX HTTP 200, estructuras y hashes registrados; apertura visual pendiente | PARCIAL |
| EVD-VIS-01 | Captura visual de PRE_G0_Humo en el portal | `ssrs-humo-portal.png`; render autenticado por `localhost`, con 99.441 pedidos y 112.650 líneas; captura recortada para excluir la identidad local | PASS |
| EVD-VIS-02 | Apertura de PDF y XLSX en aplicaciones de escritorio | Exportaciones generadas y verificadas estructuralmente; apertura en visor PDF y Excel todavía pendiente | PENDIENTE |
| PRE-G0-08 | Power BI Live a SSAS | SSAS y PBIX excluidos por el alcance corregido | NOT_IN_SCOPE |

Las seis exportaciones locales se guardan en `validacion/salidas/`, ignorado por Git; sus hashes están en el informe de resultados. No se incluyen exportaciones ni identificadores de pedidos en el repositorio. La captura visual `ssrs-humo-portal.png` excluye la identidad local y los datos de pedidos; SHA-256 `B7932E6DC7E43CD3DD31FFB1B4561BEC70E09DBF65DE844A24033F5F1F735540`. El informe temporal de humo permanece publicado en `/OLIST360/Pruebas/PRE_G0_Humo` para que pueda revisarse desde `http://localhost/Reports`; retirarlo al cerrar la revisión local.
