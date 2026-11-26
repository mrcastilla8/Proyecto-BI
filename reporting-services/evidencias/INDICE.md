# Índice de evidencias M01–M05

Estado observado el 2026-11-26. Las ejecuciones SQL locales están registradas en `validacion/matriz.csv` y `validacion/RESULTADOS_M01_M02.md`. No se inventan capturas, publicaciones ni exportaciones.

| ID | Evidencia | Resultado disponible | Estado |
|---|---|---|---|
| EVD-SSRS-01 | Versión SSRS y estado del servicio | WMI identifica SSRS Developer `16.0.1122.6`; `SQLServerReportingServices` está `Running` con inicio `Auto`. MSI de Report Builder firmado por Microsoft; instalación aún pendiente de reparación/elevación | PARCIAL |
| EVD-SSRS-02 | Catálogo y servicio SSRS | Servicio activo; `ReportServer` y `ReportServerTempDB` aún no existen | BLOCKED |
| EVD-SSRS-03 | Web Service URL y Web Portal URL | Ambas URLs estándar en `localhost:80` rechazan conexión | BLOCKED |
| EVD-SSRS-04 | Roles Browser/Content Manager y no autorizado | Se excluyeron las pruebas de cuentas/roles por la simplificación solicitada | NOT_IN_SCOPE |
| EVD-SSRS-05 | Origen compartido BI_OLIST_DW | Pendiente de catálogo y portal | BLOCKED |
| EVD-SSRS-06 | Humo PRE_G0_Humo en el portal | Conteos SQL locales reales disponibles; el RDL no se publicó ni ejecutó en SSRS | BLOCKED |
| EVD-SSRS-07 | Publicación conjunta de diez RDL | R07 y R08 están preparados localmente; faltan los otros ocho RDL | PENDIENTE |
| EVD-SSRS-08 | Exportaciones PDF y Excel del humo | No hay archivos; todavía no se puede ejecutar desde el portal | BLOCKED |
| SQL-LOCAL-R07 | Validación de consulta y total R07 | 99.441 pedidos; 99.440 con pago; 1 sin pago; importe observado `16008872.1200` | PASS |
| SQL-LOCAL-R08-01 | Pedido de varias líneas | 1 cabecera y 2 líneas; pago agregado presente | PASS |
| SQL-LOCAL-R08-02 | Pedido inexistente | 0 filas de cabecera y 0 filas de detalle | PASS |
| PRE-G0-08 | Conexión Power BI Live a SSAS | Fuera del alcance de la corrección solicitada | NOT_IN_SCOPE |

Las capturas de informe ejecutado, las exportaciones y sus hashes se agregarán después de configurar el portal. Las capturas se redactarán para ocultar identidad local y datos identificables.
