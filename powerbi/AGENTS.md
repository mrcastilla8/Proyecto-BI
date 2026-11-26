# Agentes Power BI
Ángel mantiene reporte, Basualdo revisa medidas. Lee contrato SSAS/issue. Conecta Live a SSAS real; no importes tablas para simular ni recrees medidas. Cuatro páginas acordadas en Nivel 1 y visuales vinculados a métricas del contrato. No inventar PBIX/PBIP vacío. Capturas y pruebas reales pendientes.

## Reglas Nivel 2 — OLIST 360° (pendiente de aprobación e implementación)
- **Alcance:** evolución a **15 páginas totales** (8 principales `P01`–`P08`, 4 tooltips `T01`–`T04` y 3 drill-through `D01`–`D03`) según `docs/nivel-2/03_ESPECIFICACION_POWER_BI.md` y `docs/nivel-2/02_SISTEMA_DISENO_VISUAL.md`.
- **Inmutabilidad semántica:** conexión Live obligatoria a `BI_OLIST_Tabular` con las **8 medidas DAX originales**. Prohibido agregar medidas DAX (incluso locales), visual calculations, columnas calculadas, tablas locales o modelo compuesto.
- **Custodia del PBIX maestro:** **Ángel** es el custodio único de `powerbi/BI_OLIST.pbix` durante la integración; los demás autores entregan avances individuales sin intentar merge binario.
- **Integración con SSRS:** enlaces URL fijos hacia SSRS sin prometer transferencia automática de filtros de Power BI. No modificar `powerbi/BI_OLIST.pbix` en la fase documental actual.
