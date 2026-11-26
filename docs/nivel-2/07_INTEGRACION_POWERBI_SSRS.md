# 07 — Integración y navegación

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Contrato de URLs
Poma registra Web Portal URL y Web Service URL. En equipo demo se recomienda loopback con directorios virtuales `Reports` y `ReportServer`; comprobar, no asumir. Las siguientes rutas son relativas a `/OLIST360` y deben respetarse. Castilla/Ángel configuran los botones en el PBIX final con URLs reales.
| Informe | Ruta relativa | Botones PBI |
|---|---|---|
| R01 | 01_Gerencia/R01_ResumenGerencial | P01 P08 |
| R02 | 01_Gerencia/R02_ConsolidadoMensual | P01 P02 P08 |
| R03 | 02_Comercial/R03_RankingVendedores | P04 P08 |
| R04 | 02_Comercial/R04_RendimientoCategorias | P03 P08 |
| R05 | 03_Operaciones/R05_EntregasRetrasadas | P05 P08 |
| R06 | 03_Operaciones/R06_Satisfaccion | P06 P08 |
| R07 | 02_Comercial/R07_ImportesPagados | P08 |
| R08 | 03_Operaciones/R08_FichaPedido | P08 |
| R09 | 03_Operaciones/R09_DesempenoRegional | P07 P08 |
| R10 | 04_Auditoria/R10_AuditoriaETL | P08 |

Ejemplo local, no URL comprobada: `http://localhost/ReportServer?/OLIST360/02_Comercial/R03_RankingVendedores&rs:Command=Render&TopN=10&EstadoVendedor=SP`. Usar nombres de parámetros exactos y URL-encoding. Botones de acceso sin parámetros dejan seleccionar en SSRS; no trasladan filtros de Power BI. Indicarlo junto al acceso. R08 sin OrderId muestra parámetro obligatorio. En Desktop, probar Ctrl+clic cuando corresponda. URL del portal separada de URL de servicio.

## Drill-through SSRS
R05→R08: acción Go to report, ruta absoluta del catálogo, `OrderId=Fields!order_id.Value`. R01→R02/R09: pasar Desde/Hasta/EstadoCliente y valores restantes por default; R02→R04 solo si equivalencia de filtros o advertencia de cambio de universo; R09→R05/R06: fechas/estado, si ciudad seleccionada indicar que destino abarca todo estado. No concatenar ID en SQL ni incluir credenciales en URL.

## Exportación y prueba reproducible
Usar menú Export de SSRS y, adicionalmente, URL `&rs:Format=PDF` o `&rs:Format=EXCELOPENXML` con parámetros válidos. En PowerShell, solo con URLs reales y sesión autorizada:
```powershell
$base = 'http://localhost/ReportServer' # sustituir si configuración difiere
$url = "${base}?/OLIST360/02_Comercial/R03_RankingVendedores&rs:Command=Render&TopN=10&EstadoVendedor=SP"
Invoke-WebRequest -Uri ($url + '&rs:Format=PDF') -UseDefaultCredentials -OutFile '.\R03.pdf'
Invoke-WebRequest -Uri ($url + '&rs:Format=EXCELOPENXML') -UseDefaultCredentials -OutFile '.\R03.xlsx'
Get-FileHash .\R03.pdf, .\R03.xlsx -Algorithm SHA256
```
Comprobar respuesta HTTP y tipo de contenido, archivo abre, no HTML de login disfrazado. No versionar exportaciones con datos de pedido individuales; evidencia redactada local y hash.

Referencias: [parámetros URL](https://learn.microsoft.com/en-us/sql/reporting-services/pass-a-report-parameter-within-a-url?view=sql-server-ver17), [exportación](https://learn.microsoft.com/en-us/sql/reporting-services/export-a-report-using-url-access?view=sql-server-ver17). Registrar 10 accesos P08, siete accesos contextuales P01–P07, tres acciones RDL y retorno/navegación manual. No exponer servidor fuera de red autorizada.
