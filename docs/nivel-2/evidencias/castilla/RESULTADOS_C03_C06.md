# Resultados de Implementación C03–C06 — Castilla

**Fecha:** 2026-11-27  
**Rama:** `castilla/nivel-2-integracion`  
**Entorno SQL:** `.\SQLEXPRESS` (`BI_OLIST`, SQL Server 2025 `17.0.1000.7`)  
**Entorno SSAS:** `.\SSASBI` (`BI_OLIST_Tabular`, SSAS `17.0.25.218`)

## 1. C03 — P01 Resumen ejecutivo (`powerbi/entregas/castilla/OLIST360_Castilla.pbip`)

- **Implementación:** Página `P01 · Resumen ejecutivo` (`c1a00000000000000001`) construida sobre `OLIST360_Plantilla` y el tema `olist360.json`.
  - **8 tarjetas KPI:** `ventas_productos_entregados`, `pedidos_entregados_con_items`, `pedidos_totales`, `ticket_promedio_productos_entregados`, `flete_pedidos_entregados`, `porcentaje_entregas_a_tiempo`, `dias_promedio_entrega`, `calificacion_promedio`.
  - **Visuales analíticos:** `P01-09` línea mensual de ventas (tooltip `T01`), `P01-10` Top 5 categorías por ventas (tooltip `T02`, con interacción `NoFilter` hacia los 8 KPI y `P01-11`), `P01-11` columnas agrupadas `pedidos_totales` vs. `pedidos_entregados_con_items` (aclarando poblaciones distintas), y `P01-12` panel de accesos a `R01`, `R02` y `P08`.
  - **Inmutabilidad semántica:** Conexión Live a `BI_OLIST_Tabular`; cero medidas DAX locales, cero columnas calculadas, cero tablas locales.
- **Validación DAX contra `.\SSASBI`:** Todos los valores de las 8 medidas en `BI_OLIST_Tabular` coinciden exactamente con SQL Server en histórico, 2017, SP, 2017+SP y vacío (`BLANK`).
- **Apertura gráfica en Power BI Desktop (`2.159.1231.0`):** Se lanzó `PBIDesktop.exe` con una copia local apuntando a `.\SSASBI`, pero el proceso no mantuvo ventana activa en la sesión automatizada sin interfaz interactiva de escritorio; la verificación visual interactiva en Power BI Desktop (incluyendo capturas y generación del `.pbix` individual) queda registrada como `BLOCKED` / pendiente de apertura manual por el usuario.

## 2. C04 — P08 Centro de informes (`powerbi/entregas/castilla/OLIST360_Castilla.pbip`)

- **Implementación:** Página `P08 · Centro de informes` (`c1a00000000000000008`), sin KPI ni segmentadores analíticos.
  - Contiene las 10 tarjetas/botones `R01`–`R10` agrupadas en **Gerencia**, **Comercial**, **Operaciones** y **Auditoría**, más el botón del portal `/OLIST360`.
  - Incluye el aviso visible: *«Los filtros de Power BI no se transfieren automáticamente a Reporting Services. Seleccione los parámetros en el informe. R08 exige OrderId, que debe introducirse en el portal.»*
  - Enlaces configurados con `{{SSRS_WEB_SERVICE_URL}}` y `{{SSRS_WEB_PORTAL_URL}}` conforme al patrón del equipo (pendiente de sustitución por la URL real del entorno SSRS de demostración).

## 3. C05 — R01 Resumen gerencial (`reporting-services/reports/R01_ResumenGerencial.rdl`)

- **Estructura:** A4 vertical (`21cm × 29.7cm`, márgenes `1,2cm`), origen compartido `/OLIST360/DataSources/BI_OLIST_DW`, parámetros `Desde`, `Hasta`, `EstadoCliente` y dos datasets independientes (`R01_ResumenDetalle` sobre `FactDetallePedido` y `R01_ResumenCabecera` sobre `FactPedidos`), más `R01_Fechas` y `R01_Estados`.
- **Coherencia `CommandText` vs SQL:** Los 4 `CommandText` del RDL coinciden byte a byte con `reporting-services/datasets/R01_*.sql`.
- **Conciliación real SQL (`.\SQLEXPRESS`) vs SSAS DAX (`.\SSASBI`) sin redondeo:**

| Escenario | `ventas` (SQL / DAX) | `entregados` | `pedidos` | `flete` | `ticket` (diff) | `puntualidad` (diff) | `dias` (diff) | `nota` (diff) | Estado |
|---|---|---|---|---|---|---|---|---|---|
| Histórico (`2016-09-04`..`2018-10-17`) | `13221498.11` | `96478` | `99441` | `2198275.64` | `0` | `1.11e-16` | `2.84e-14` | `0` | **PASS** |
| Año `2017` | `5962902.01` | `43428` | `45101` | `958633.23` | `0` | `0` | `0` | `0` | **PASS** |
| Estado `SP` | `5067633.16` | `40501` | `41746` | `702069.99` | `0` | `0` | `5.33e-15` | `0` | **PASS** |
| Año `2017` + `SP` | `2136258.96` | `17071` | `17760` | `291743.66` | `0` | `0` | `7.11e-15` | `0` | **PASS** |
| Vacío (`2015`) | `NULL` / `BLANK` | `0` / `BLANK` | `0` / `BLANK` | `NULL` / `BLANK` | `NULL` / `BLANK` | `NULL` / `BLANK` | `NULL` / `BLANK` | `NULL` / `BLANK` | **PASS** |
| Rango inválido (`2018-01-01`..`2017-01-01`) | `NULL` | `0` | `0` | `NULL` | `NULL` | `NULL` | `NULL` | `NULL` | **PASS** |

- **Bloqueo local:** Report Builder y SSRS no están instalados localmente; renderizado visual y exportación PDF/XLSX pendientes en entorno SSRS de Poma/demo.

## 4. C06 — R10 Auditoría ETL (`reporting-services/reports/R10_AuditoriaETL.rdl`)

- **Estructura:** A4 horizontal (`29,7cm × 21cm`, márgenes `1,2cm`), parámetros `DesdeEjecucion`, `HastaEjecucion`, `Fuente`, `EstadoLote`.
- **Datasets versionados:** `R10_FechasEjecucion.sql`, `R10_Fuentes.sql`, `R10_EstadosLote.sql`, `R10_AuditoriaETL.sql`, `R10_ResumenAuditoria.sql`. Todos coinciden byte a byte con el `CommandText` del RDL.
- **Pruebas SQL reales en `.\SQLEXPRESS` (`BI_OLIST`):**
  - Lotes `COMPLETE` auténticos: `10` lotes (`batch_id` `60`–`68` de `Ingesta` y `69` de `DW.Transformacion`), `1.550.922` filas aceptadas, `0` rechazadas, `0` registros en `audit.Reject`, todos con estado `CONCILIADO`.
  - Resumen por fuente y estado: `10` filas, distinguiendo `Ingesta` vs `Transformacion` y orden de recencia (`Último` vs `Reintento`) sin sumar reintentos históricos como carga vigente.
  - Privacidad: Sin proyección de `source_file`, `error_message`, `execution_context` ni filas individuales de `audit.Reject`.
  - Intervalo sin resultados (`2025-01-01`..`2025-01-02`): `0` filas.
  - Rango inválido (`2026-12-31`..`2026-01-01`): `0` filas.
- **Bloqueo local:** Renderizado en Report Builder y exportación PDF/XLSX pendientes en entorno SSRS de Poma/demo; prueba de lote `FAILED` en fixture aislada pendiente de entorno SSRS/LocalDB dedicado si se requiere captura visual.
