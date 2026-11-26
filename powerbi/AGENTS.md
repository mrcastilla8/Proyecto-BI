# Agentes Power BI

## Línea base Nivel 1 (implementada y congelada en `powerbi/BI_OLIST.pbix`)
Ángel mantiene el reporte y Basualdo revisa las medidas. Lee contrato SSAS/issue. Conecta Live a SSAS real; no importes tablas para simular ni recrees medidas. La línea base de Nivel 1 comprende cuatro páginas implementadas y verificadas con sus visuales vinculados a las ocho métricas del contrato v1. No inventar PBIX/PBIP vacío ni borrar evidencias históricas del Nivel 1.

## Alcance planificado Nivel 2 — OLIST 360° (pendiente de aprobación e implementación)
- **Evolución de páginas:** tras aprobar `ADR-0002` y superar `G1`, el reporte evolucionará de las 4 páginas actuales a **15 páginas totales** (8 principales `P01`–`P08`, 4 tooltips `T01`–`T04` y 3 drill-through `D01`–`D03`) según `docs/nivel-2/03_ESPECIFICACION_POWER_BI.md` y `docs/nivel-2/02_SISTEMA_DISENO_VISUAL.md`.
- **Inmutabilidad semántica:** conexión Live obligatoria a `BI_OLIST_Tabular` con las **8 medidas DAX originales**. Prohibido agregar medidas DAX (incluso locales), visual calculations, columnas calculadas, tablas locales o modelo compuesto.
- **Custodia del PBIX maestro:** **Ángel** es el custodio único de `powerbi/BI_OLIST.pbix` durante la integración; los demás autores entregan avances individuales sin intentar merge binario.
- **Integración con SSRS:** enlaces URL fijos hacia SSRS sin prometer transferencia automática de filtros de Power BI. No modificar `powerbi/BI_OLIST.pbix` durante la fase documental actual.
