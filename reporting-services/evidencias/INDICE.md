# Índice de evidencias M01/M02

Estados observados el 2026-11-26. Una evidencia SSRS `PASS` requiere ejecución real en Windows; este índice no sustituye una captura/exportación.

| ID | Evidencia requerida | Evidencia disponible | Estado |
|---|---|---|---|
| EVD-SSRS-01 | Versiones de Windows, SQL, SSAS, Power BI Desktop, Report Builder y SSRS | Inventario textual parcial en `validacion/RESULTADOS_M01_M02.md`; SSRS/Report Builder/SSAS faltantes | PARCIAL / BLOCKED |
| EVD-SSRS-02 | Catálogo `ReportServer`/`ReportServerTempDB` y servicio activo | Consulta de inventario: no están creados/no hay servicio | BLOCKED |
| EVD-SSRS-03 | Web Service URL y Web Portal URL activos | No existen endpoints SSRS configurados | BLOCKED |
| EVD-SSRS-04 | Browser, no autorizado rechazado y sin permiso de publicación | No hay portal/roles contra los que probar | BLOCKED |
| EVD-SSRS-05 | Origen compartido y permisos SQL sin DML | RDL referencia y aprovisionador con comprobaciones; no hay origen/login configurado | BLOCKED |
| EVD-SSRS-06 | Diez informes RDL definitivos publicados (G3) | Fuera de M01/M02; no se implementaron R01–R10 | NOT_IN_SCOPE |
| EVD-SSRS-07 | Matriz real de ejecución de los diez informes (G3/G4) | Fuera de M01/M02; pendiente del trabajo posterior | NOT_IN_SCOPE |
| EVD-SSRS-08 | Exportaciones válidas de humo PDF/XLSX | Verificador de exportación preparado; no existe ejecución/exportación | BLOCKED |
| PRE-G0-06 | Humo agregado publicado y ejecutado | SQL/RDL local preparado; ejecución portal no disponible | BLOCKED |
| PRE-G0-08 | Conexión Live de Power BI a SSAS | Proceso SSAS de espacio de trabajo activo en Visual Studio con puerto dinámico; el endpoint guardado antes en Power BI no escucha; no se modificó el PBIX | BLOCKED |

No se guardan capturas ficticias, PDFs, XLSX, credenciales, nombres de cuenta ni filas de pedidos. Cuando se complete la instalación, adjuntar aquí solo capturas redactadas (sin nombres personales/secretos) y hashes de archivos agregados.
