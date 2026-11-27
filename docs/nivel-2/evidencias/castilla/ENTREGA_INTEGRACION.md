# Manifiesto de Integración Nivel 2 — OLIST 360° (C07)

**Responsable de coordinación:** Castilla (`@mrcastilla8`)  
**Custodio exclusivo del PBIX maestro:** Ángel (`@luisdem01`)  
**Custodio de publicación SSRS:** Poma (`@GabrielPGu`)

> [!IMPORTANT]
> `powerbi/BI_OLIST.pbix` no ha sido modificado en esta rama (`castilla/nivel-2-integracion`), respetando la regla de escritor único.

## 1. Inventario de páginas Power BI a integrar en `powerbi/BI_OLIST.pbix`

| Código | Página | Propietario | Origen PBIP en repositorio | ID de página sugerido / actual | Dependencias |
|---|---|---|---|---|---|
| `P01` | Resumen ejecutivo | Castilla | `powerbi/entregas/castilla/OLIST360_Castilla.Report` | `c1a00000000000000001` | `T01`, `T02`, `P08`, URLs `R01`/`R02`, sync `olist360_fecha_compra` y `olist360_estado_cliente` |
| `P02` | Inteligencia comercial | Ángel | `powerbi/entregas/angel/OLIST360_Angel.Report` | `da5b9a12743d7f7f6922` | `T01`, URL `R02`, sync fechas/estado |
| `P03` | Productos y categorías | Ángel | `powerbi/entregas/angel/OLIST360_Angel.Report` | `74b873de5e25d747193b` | `T02`, `D01`, URL `R04`, filtros locales `Cat`/`Prod` |
| `P04` | Desempeño de vendedores | Cueva | `powerbi/entregas/cueva/OLIST360_Cueva.Report` | Ver entrega Cueva | `D02`, URL `R03`, filtros locales `EV`/`Vend` |
| `P05` | Logística | Cueva | `powerbi/entregas/cueva/OLIST360_Cueva.Report` | Ver entrega Cueva | `T03`, URL `R05`, filtro `order_status` |
| `P06` | Experiencia del cliente | Basualdo | `powerbi/entregas/basualdo/` | Ver entrega Basualdo | `T04`, URL `R06` |
| `P07` | Inteligencia geográfica | Basualdo | `powerbi/entregas/basualdo/` | Ver entrega Basualdo | `T04`, `D03`, URL `R09`, TopoJSON 27 UF |
| `P08` | Centro de informes | Castilla | `powerbi/entregas/castilla/OLIST360_Castilla.Report` | `c1a00000000000000008` | Navegación P01–P08 y 10 botones URL `R01`–`R10` + Portal SSRS |
| `T01` | Tooltip temporal (oculta) | Ángel | `powerbi/entregas/angel/OLIST360_Angel.Report` | `c6eb53669c7346ba553f` | Reutilizada por P01-09 y P02 (no duplicar la copia local `c1a000000000000000a1` de Castilla) |
| `T02` | Tooltip categoría/producto (oculta) | Ángel | `powerbi/entregas/angel/OLIST360_Angel.Report` | `8dbf4d91c8076fdf07a9` | Reutilizada por P01-10 y P03 (no duplicar la copia local `c1a000000000000000a2` de Castilla) |
| `T03` | Tooltip logística (oculta) | Cueva | `powerbi/entregas/cueva/OLIST360_Cueva.Report` | Ver entrega Cueva | Reutilizada por P05 |
| `T04` | Tooltip geográfico (oculta) | Basualdo | `powerbi/entregas/basualdo/` | Ver entrega Basualdo | Reutilizada por P06 y P07 |
| `D01` | Detalle de producto (oculta) | Ángel | `powerbi/entregas/angel/OLIST360_Angel.Report` | `7eddb218f0ef94b13388` | Drill-through desde `Prod` en P03 |
| `D02` | Detalle de vendedor (oculta) | Cueva | `powerbi/entregas/cueva/OLIST360_Cueva.Report` | Ver entrega Cueva | Drill-through desde `Vend` en P04 |
| `D03` | Detalle de estado (oculta) | Basualdo | `powerbi/entregas/basualdo/` | Ver entrega Basualdo | Drill-through desde `EC` en P07 |

## 2. Catálogo completo de 10 informes RDL en `reporting-services/reports/`

Todos los RDL existen en el repositorio y deben publicarse bajo `/OLIST360` en el servidor SSRS de demostración:

| ID | Archivo RDL en repositorio | Ruta oficial SSRS (`/OLIST360/...`) | Estado de URL en PBI |
|---|---|---|---|
| `R01` | `R01_ResumenGerencial.rdl` | `01_Gerencia/R01_ResumenGerencial` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` (pendiente de entorno demo) |
| `R02` | `R02_ConsolidadoMensual.rdl` | `01_Gerencia/R02_ConsolidadoMensual` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R03` | `R03_RankingVendedores.rdl` | `02_Comercial/R03_RankingVendedores` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R04` | `R04_RendimientoCategorias.rdl` | `02_Comercial/R04_RendimientoCategorias` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R05` | `R05_EntregasRetrasadas.rdl` | `03_Operaciones/R05_EntregasRetrasadas` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R06` | `R06_Satisfaccion.rdl` | `03_Operaciones/R06_Satisfaccion` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R07` | `R07_ImportesPagados.rdl` | `02_Comercial/R07_ImportesPagados` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R08` | `R08_FichaPedido.rdl` | `03_Operaciones/R08_FichaPedido` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` (exige `OrderId` en portal) |
| `R09` | `R09_DesempenoRegional.rdl` | `03_Operaciones/R09_DesempenoRegional` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |
| `R10` | `R10_AuditoriaETL.rdl` | `04_Auditoria/R10_AuditoriaETL` | Placeholder `{{SSRS_WEB_SERVICE_URL}}` |

## 3. Pasos exactos para Ángel al integrar P01 y P08 en el maestro

1. Incorporar `P01` (`c1a00000000000000001`) y `P08` (`c1a00000000000000008`) en `powerbi/BI_OLIST.pbix` sin copiar `c1a000000000000000a1`/`a2` (conservar los `T01`/`T02` únicos del maestro).
2. Reasignar los tooltips de `P01-09` (línea mensual) a `T01` y `P01-10` (Top 5 categorías) a `T02`.
3. Verificar que `P01-10` mantiene interacción `NoFilter` hacia `P01-01..08` y `P01-11`.
4. Conectar los 8 botones del menú lateral (`P01`–`P08`) y el botón `Ir a P08` de `P01-12` a sus páginas reales.
5. En el equipo de demostración con SSRS activo, sustituir `{{SSRS_WEB_SERVICE_URL}}` y `{{SSRS_WEB_PORTAL_URL}}` por las URLs reales verificadas.
