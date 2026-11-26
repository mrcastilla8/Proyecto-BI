# Contexto y alcance

## Preguntas
¿Qué precio de productos entregados se observa por tiempo/categoría? ¿Cuántos pedidos con líneas entregadas hay? ¿Cómo se compara cumplimiento de promesa por fecha/estado? ¿Qué productos/vendedores concentran líneas y flete? ¿Qué calificación media por pedido se observa por geografía?

## Nivel 1 (implementado y verificado)
Descarga manual; nueve fuentes Olist; staging, ETL SSIS, dimensiones/hechos SQL Server, SSAS Tabular con relaciones/jerarquías/DAX, Power BI Live de cuatro páginas; controles, evidencia e informe reproducible (evidencia integrada del `20-11-2026` en `ssas/README.md` y `powerbi/evidencias/INDICE.md`). Tecnologías obligatorias: Visual Studio Community con extensiones SSIS/Analysis Services Projects, SQL Server, SSMS, SSIS, SSAS Tabular, Power BI Desktop, Git/GitHub. Python estándar solo para validaciones, documentación y fixtures.

Fuera del alcance: ML de riesgo logístico, tiempo real, Azure/cloud, APIs y servicios públicos; solo se listan como mejoras futuras sin scaffolding. Los archivos CSV originales no se versionan en el repositorio.

## Nivel 2 — OLIST 360° (alcance aprobado; implementación pendiente)
Ampliación de la capa de consumo solicitada por el docente bajo el nombre **OLIST 360° — Business Intelligence Suite** (`docs/nivel-2/` y `ADR-0002`, estado **`ACEPTADO`** por `mrcastilla8` el `2026-11-26` en el PR `#14`, con entrada en vigor tras el merge):
- **Power BI Desktop (Live sobre SSAS):** evolución de 4 a **15 páginas totales** (8 principales `P01`–`P08`, 4 tooltips `T01`–`T04` y 3 drill-through `D01`–`D03`) con sistema de diseño unificado (`olist360.json`) y enlaces fijos hacia SSRS.
- **Microsoft SQL Server Reporting Services (SSRS 2022 Developer, Native Mode):** **10 informes paginados RDL** (`R01`–`R10`) alimentados por consultas SQL `SELECT` parametrizadas de solo lectura sobre `BI_OLIST.dw` y `audit` agregado, con exportación PDF y Excel (`EXCELOPENXML`).
- **Alcance congelado:** se conservan intactos `database/`, `contracts/`, `ssis/`, `ssas/BI_OLIST_Tabular/Model.bim` y las **8 medidas DAX originales**. Prohibido agregar medidas DAX, cambiar granos o exponer datos sensibles.
- **Planificación:** 39 tareas individuales distribuidas entre los 5 integrantes (`docs/nivel-2/guias/`) y 29 casos de certificación en `docs/nivel-2/08_PRUEBAS_CERTIFICACION.md`. Estado actual: alcance documental aprobado; **implementación y certificación práctica pendientes** (`NOT_RUN`).
