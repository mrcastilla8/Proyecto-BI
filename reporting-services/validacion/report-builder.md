# R06 y R09 en Microsoft Report Builder

Prueba local del 26/11/2026 en Windows sobre `BI_OLIST`, con el DW y los datasets versionados. Para reproducirla, abre una copia de cada RDL en Microsoft Report Builder, usa un origen SQL Server incrustado para el DW local con autenticación de Windows y ejecuta el informe con estos filtros. Desde la vista previa, selecciona **Exportar → PDF** y **Exportar → Excel**.

| Informe y filtros | Resultado observado | Evidencia |
|---|---|---|
| R06 · 01/01/2017–31/12/2017, SP, notas de 3,25 a 4,5 | 3.427 notas y promedio 4,00. Los rangos [3,4) y [4,5) reúnen 8 y 3.419 notas. Los doce meses suman 3.427. | [Vista previa](../evidencias/R06-report-builder.jpg) · [PDF](../evidencias/R06-2017-SP.pdf) · [Excel](../evidencias/R06-2017-SP.xlsx) · [Cotejo SQL](R06.md) |
| R09 · 01/01/2017–31/12/2017, SP, São Paulo | El total, el estado y la ciudad coinciden en R$ 752.425,64, 6.381 pedidos, 6.123 entregados, 95,93 % de puntualidad y nota 4,12. Cada nivel se cotejó por separado. | [Vista previa](../evidencias/R09-report-builder.jpg) · [PDF](../evidencias/R09-2017-SP-sao-paulo.pdf) · [Excel](../evidencias/R09-2017-SP-sao-paulo.xlsx) · [Cotejo SQL](R09.md) |

Los PDF tienen una página A4 horizontal cada uno (`pdfinfo`). El render con `pdftoppm` permitió revisar filtros, tablas y pie de página sin recortes. Cada XLSX contiene una hoja íntegra, sin celdas de error. En el XML de las hojas se comprobaron los importes, conteos, porcentajes y notas como valores numéricos. Las seis evidencias contienen resultados agregados.

La primera ejecución detectó que faltaba la cuadrícula de parámetros. Se añadió una celda por parámetro en cada RDL. En R09 también se abrevió el encabezado de entregas y se sustituyó el carácter de la barra que se mostraba como un cuadro. Las pruebas de publicación, resolución del origen compartido, enlaces entre informes y exportación HTTP quedan pendientes del portal SSRS.
