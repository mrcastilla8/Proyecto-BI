# M06–M07 — integración y exportaciones SSRS (corte parcial)

**Fecha de ejecución:** 2026-11-27 · **Rama:** `poma/nivel-2-reporting` · **HEAD de los RDL probados:** `e15fede1928518f096cd8e2b0edcd456af9cf41c` · **Entorno:** Windows 11 Home 25H2, SQL Server Developer `17.0.1000.7`, SSRS Developer Native Mode `16.0.1122.6`, Report Builder `15.1.30001.02`.

Este corte registra seis de los diez informes publicados en el SSRS local: R02, R04, R06, R07, R08 y R09. La rama local parte del mismo commit que `master` remoto al momento de la prueba. Los cuatro RDL de Ángel y Basualdo estaban ya en ese commit; no se modificaron para esta integración.

## Servicio y origen usados

- Portal local: `http://localhost/Reports`.
- Servicio de informes: `http://localhost/ReportServer`.
- Origen compartido: `/OLIST360/DataSources/BI_OLIST_DW`, conectado a `BI_OLIST` con autenticación integrada.
- Las seis rutas publicadas aparecen en el índice de evidencias. Las ejecuciones y exportaciones consultaron el Data Mart real; no se ejecutó DDL ni DML.

Usar `localhost` para la sesión Windows local. `127.0.0.1` había abierto un diálogo de autenticación en Brave.

## Ejecución de informes y parámetros

| Informe / ruta | Parámetros ejecutados | Resultado observado |
|---|---|---|
| R02 — `/OLIST360/01_Gerencia/R02_ConsolidadoMensual` | 01/01/2017–31/12/2017; todos los estados de cliente; todas las categorías | 12 meses; ventas **R$ 5.962.902,01**; **43.428** pedidos entregados; ticket **R$ 137,31**; flete **R$ 958.633,23**. PDF de 1 página; XLSX abierto en Excel. |
| R04 — `/OLIST360/02_Comercial/R04_RendimientoCategorias` | 01/01/2017–31/12/2017; todas las categorías | La primera categoría fue `bed_bath_table`, con ventas de **R$ 490.596,92** y **4.423** pedidos entregados. PDF de 4 páginas; XLSX abierto en Excel. |
| R06 — `/OLIST360/03_Operaciones/R06_Satisfaccion` | 01/01/2017–31/12/2017; estado `SP`; nota de 1 a 5 | **17.614** notas válidas; promedio mostrado **4,15**. PDF de 1 página; XLSX abierto en Excel. |
| R07 — `/OLIST360/02_Comercial/R07_ImportesPagados` | 04/09/2016–17/10/2018; todos los estados | **162** agregados; **99.441** pedidos; **99.440** con pago observado y **1** sin pago observado; total observado **R$ 16.008.872,12**. PDF de 6 páginas; XLSX abierto en Excel. |
| R08 — `/OLIST360/03_Operaciones/R08_FichaPedido` | Identificador de un pedido existente, conservado solo localmente | Se comprobó cabecera, dos líneas y pago agregado; también se ejecutó un identificador inexistente y las consultas devolvieron cero cabeceras y cero líneas. PDF de 1 página y XLSX generados y revisados localmente. El identificador y las exportaciones de detalle no se incluyen en Git. |
| R09 — `/OLIST360/03_Operaciones/R09_DesempenoRegional` | 01/01/2017–31/12/2017; estado `SP`; ciudad `sao paulo` | **6.381** pedidos, **6.123** entregados, ventas **R$ 752.425,64**, flete **R$ 100.270,40**, puntualidad **95,93 %**, entrega media **8,64 días** y nota **4,12**. PDF de 1 página; XLSX abierto en Excel. |

Los parámetros descritos son los seleccionados durante cada ejecución. No se cambió ningún RDL ni contrato.

## Revisión de exportaciones

Se generaron los seis pares PDF/XLSX desde SSRS. Los seis XLSX se abrieron y mostraron contenido en Excel. Los seis PDF se renderizaron localmente con Poppler y se revisó su salida visual; las vistas PNG de la página 1 de R02, R04, R06, R07 y R09 se incluyen en `evidencias/renderizados-2026-11-27/`. La vista de R08 y sus archivos de exportación quedan en `validacion/salidas/`, ignorada por Git, porque contienen datos de un pedido individual.

Excel mostró la advertencia de activación de producto en el título de la ventana, pero permitió abrir y leer los seis libros. En R09, el indicador gráfico “Ventas vs. máximo” sale como barras verticales repetidas en el PDF; las métricas tabulares se leen y coinciden con la ejecución. Es una limitación visual que queda registrada.

### SHA-256 de los RDL fuente probados

Estos hashes identifican la copia versionada en el HEAD de la prueba; no afirman una comparación binaria con los elementos almacenados internamente en el catálogo SSRS.

| RDL | SHA-256 |
|---|---|
| `R02_ConsolidadoMensual.rdl` | `4E2A95030D5CDFAD596410949AF91304A9E2A1CC46AE19828C8535C8448A435E` |
| `R04_RendimientoCategorias.rdl` | `1BD3476A3F2BE11994E6470EA7752BE6A331A9F87707DF0C61228493785EC767` |
| `R06_Satisfaccion.rdl` | `A6191E718DE9B4BEC046F9C2872B4FB50023F885BA8CAACC4D1F59B21BB06600` |
| `R07_ImportesPagados.rdl` | `D6F309E3E75345A1E8A0DE74FF0DF22D5E3837F18A3A28E4A142EBF1E8052EA9` |
| `R08_FichaPedido.rdl` | `05923CE1C31A68C214F3FFE817AB0EF48C92BB5764E3AF229496AE1E0210B68D` |
| `R09_DesempenoRegional.rdl` | `7EE2A679FC6AA2A7F4B1AFCFC9A8E3396EDAFCBD36B217EEEDC8C754DB88653A` |

### SHA-256 de exportaciones agregadas

Los cinco informes listados no contienen identificadores de pedidos individuales. R08 se excluye de esta tabla por la política de datos; sus archivos y captura se mantienen localmente en la carpeta ignorada.

| Informe | PDF (bytes) | SHA-256 PDF | XLSX (bytes) | SHA-256 XLSX |
|---|---:|---|---:|---|
| R02 | 226720 | `D26759D0B0FC9644FACFD3F59BC935913DD2B85EB84F0C4584A8667CD65FD4A3` | 20221 | `0EB5FA7B8FA25950AB2A82B587B2703EA8C0285870D0DCABA380C33D22F06818` |
| R04 | 237965 | `6740C0A1C8C494C6E53A6D030BCE02BC79C2472CD617C83B0B657B3484FAEDDD` | 859142 | `1F475A5A0B703F8771EA78EABC168A93D1674BA1617CD3373E6F8BB7D2D45ADE` |
| R06 | 187350 | `9C2FB70778990A47F34F4EF2A945A6274B25BC673968137E452492710E1796D5` | 6212 | `941635DE7CBC542C0F90DC2807E7BE6CB63AA68D4AAF8664F4336A7A181A12A8` |
| R07 | 276611 | `08FE02151B40A3445D0E00A020AA170A49AF6FCFC2AB3B9CE9FE054107D5C2C1` | 22290 | `4804C66E6110F8FE5285E9049B75DDF2441A2FC575116508638B7FF54B1FA09A` |
| R09 | 194560 | `BE8519AA96468E8F201827F04639943F59BA16FA653394A871174285A067C143` | 6984 | `6FCB741252065B4186EAC65EB45BB6F363CA9225B002E73109F8640284FF0ED8` |

## Vistas verificadas

Las imágenes son la página inicial de la exportación PDF real, no una captura simulada. La imagen de R08 permanece local por la misma regla de privacidad.

| Informe | Vista |
|---|---|
| R02 | ![R02, página 1 del PDF SSRS](../evidencias/renderizados-2026-11-27/R02-SSRS-1.png) |
| R04 | ![R04, página 1 del PDF SSRS](../evidencias/renderizados-2026-11-27/R04-SSRS-1.png) |
| R06 | ![R06, página 1 del PDF SSRS](../evidencias/renderizados-2026-11-27/R06-SSRS-1.png) |
| R07 | ![R07, página 1 del PDF SSRS](../evidencias/renderizados-2026-11-27/R07-SSRS-1.png) |
| R08 | Inspección local: `validacion/salidas/R08-SSRS-1.png`; excluida del commit por contener detalle del pedido. |
| R09 | ![R09, página 1 del PDF SSRS](../evidencias/renderizados-2026-11-27/R09-SSRS-1.png) |

## Validaciones, resultado y pendientes

- `python scripts/validar_base.py`: **PASS** el 2026-11-27.
- `reporting-services/scripts/Verificar-CatalogoSSRS.ps1 -SqlServerInstance localhost -PortalUrl http://localhost/Reports -ReportServerUrl http://localhost/ReportServer -TrustServerCertificate`: **PASS**; portal y SOAP HTTP 200, ambos catálogos ONLINE y servicio SSRS `Running`. La primera ejecución dentro del sandbox fue bloqueada por acceso a socket/CIM; el mismo chequeo de solo lectura se repitió con permiso local y terminó PASS.
- `reporting-services/scripts/Validar-Scripts.ps1`: **PASS**; siete scripts PowerShell parsean sin errores.
- `git diff --check`: **PASS** tras actualizar esta evidencia.
- La verificación de SSRS local y la ejecución de los seis RDL se hicieron en Windows contra el servicio local y `BI_OLIST`. No se hicieron cambios de DDL/DML.
- R02, R04, R06, R07, R08 y R09: **6/10** publicados y ejecutados.
- R01, R03, R05 y R10 siguen pendientes de publicación/prueba. Por eso los criterios globales M06 y M07 y las evidencias oficiales EVD-SSRS-06, EVD-SSRS-07 y EVD-SSRS-08 permanecen **PARCIAL (6/10)**.
- La prueba visual de exportaciones del informe de humo PRE_G0_Humo continúa pendiente; su caso `PRE-G0-07` no se cambia a PASS por esta revisión.
- No se modificaron `database/`, `contracts/`, `ssis/`, `ssas/`, DAX ni el PBIX maestro. No se creó ningún issue y no se hizo merge.
