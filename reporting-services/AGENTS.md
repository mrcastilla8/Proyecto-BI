# Agentes Reporting Services (SSRS 2022)

Manual operativo para el desarrollo, revisión, publicación y validación de los 10 informes paginados RDL del Nivel 2 (**OLIST 360° — Business Intelligence Suite**, `ADR-0002` **`ACEPTADO`** por `mrcastilla8` el `2026-11-26` en el PR `#14`, con entrada en vigor tras el merge). Este documento es normativo; durante la fase de cierre documental no se instalan servicios ni se crean archivos `.rdl` ni proyectos simulados.

## 1. Roles y responsables

- **Servidor, proyecto compartido y publicación:** **Poma** (`@GabrielPGu`) es responsable de la infraestructura SSRS 2022 Developer (Native Mode), el catálogo `ReportServer`/`ReportServerTempDB`, la seguridad del portal `/OLIST360`, el proyecto compartido (si aplica), la publicación de los 10 RDL y la verificación final de exportaciones.
- **Revisor SQL:** **Cueva** (`@AXL031`) revisa todas las consultas `SELECT`/`CTE`, granularidad, predicados, guardas de parámetros y ausencia de doble conteo en `R01`–`R10`.
- **Revisor semántico:** **Basualdo** (`@MarcosBasualdoAle`) revisa la conciliación numérica y semántica frente a las 8 medidas DAX originales de SSAS Tabular (y en `R01`/`R10`, donde participa Castilla, revisan Basualdo o Poma).
- **Integración y certificación:** **Castilla** (`@mrcastilla8`) coordina la integración Power BI ↔ SSRS, aprueba plantillas y certifica el cierre en `G4` sobre los 29 casos de `docs/nivel-2/08_PRUEBAS_CERTIFICACION.md`.

### Responsables por informe RDL

| ID | Informe | Ruta relativa en `/OLIST360` | Autor |
|---|---|---|---|
| `R01` | Resumen gerencial | `01_Gerencia/R01_ResumenGerencial` | Castilla |
| `R02` | Consolidado mensual de ventas | `01_Gerencia/R02_ConsolidadoMensual` | Ángel |
| `R03` | Ranking de vendedores | `02_Comercial/R03_RankingVendedores` | Cueva |
| `R04` | Rendimiento por categorías | `02_Comercial/R04_RendimientoCategorias` | Ángel |
| `R05` | Entregas retrasadas | `03_Operaciones/R05_EntregasRetrasadas` | Cueva |
| `R06` | Satisfacción | `03_Operaciones/R06_Satisfaccion` | Basualdo |
| `R07` | Importes pagados | `02_Comercial/R07_ImportesPagados` | Poma |
| `R08` | Ficha de pedido | `03_Operaciones/R08_FichaPedido` | Poma |
| `R09` | Desempeño regional | `03_Operaciones/R09_DesempenoRegional` | Basualdo |
| `R10` | Auditoría ETL | `04_Auditoria/R10_AuditoriaETL` | Castilla |

## 2. Reglas de consultas SQL y solo lectura

- **Consultas permitidas:** exclusivamente `SELECT` y `CTE` parametrizados según `docs/nivel-2/06_CONTRATO_CONSULTAS_SQL.md` y `docs/nivel-2/05_CATALOGO_INFORMES_RDL.md`.
- **Prohibiciones estrictas:**
  - Prohibido ejecutar DML (`INSERT`, `UPDATE`, `DELETE`, `MERGE`) o DDL.
  - Prohibido modificar el esquema dimensional (`database/`), crear vistas, procedimientos almacenados, índices o tablas nuevas en `BI_OLIST`.
  - Prohibido modificar directamente las tablas internas del catálogo de SSRS (`ReportServer` / `ReportServerTempDB`); toda administración del catálogo se realiza mediante Reporting Services Configuration Manager, el portal web o APIs soportadas.
  - Prohibido leer `stg` para informes. En `R10`, consultar `audit.Batch` y conteos agregados de `audit.Reject` sin exponer `error_message`, `source_file`, `execution_context` ni registros individuales de rechazo.
- **Validación `CommandText` vs. SQL versionado:** cada consulta embebida (`CommandText`) dentro de un `.rdl` debe coincidir exactamente con su archivo SQL de referencia versionado en `reporting-services/datasets/`. Cualquier discrepancia constituye fallo de revisión.

## 3. Protección de credenciales y datos

- El origen compartido (`BI_OLIST_DW` y, si se separa, `BI_OLIST_AUDIT`) debe usar una identidad de lectura dedicada (`SELECT` mínimo necesario), nunca `sysadmin` ni `db_owner`.
- El portal SSRS autentica usuarios Windows (rol `Browser` para lectura, sin permisos de publicación para usuarios finales).
- Prohibido versionar contraseñas, claves de cifrado, encabezados de autenticación, rutas personales absolutas o exportaciones con datos de pedidos individuales en Git.

## 4. Exportaciones, evidencias y publicación

- **Exportaciones obligatorias:** todo informe debe validar exportación real a **PDF** y **Excel (`EXCELOPENXML`)**, comprobando apertura del archivo, ausencia de recortes o páginas en blanco, formato numérico utilizable (`R$` y fechas `dd/MM/yyyy`) y respuesta HTTP válida (no HTML de error/login).
- **Requisitos por entrega RDL:** parámetros tipados y guardas contra rangos inválidos, origen compartido resuelto, mensaje explícito cuando no hay datos, paginación y encabezado/pie según `docs/nivel-2/02_SISTEMA_DISENO_VISUAL.md`.
- **Evidencia y publicación:** registrar URL real del portal, hash SHA-256 de cada RDL publicado, fecha, HEAD, filtro usado y resultado en `reporting-services/validacion/matriz.csv` y `EVD-SSRS-01`..`08` (`docs/nivel-2/04_ESPECIFICACION_REPORTING_SERVICES.md`). No declarar `PASS` sin ejecución real en Windows.
