# Roadmap

## Nivel 1 (implementado y verificado)
DDL SQL (`18-11-2026`), carga SSIS completa, Data Mart, SSAS Tabular/DAX conciliado y Power BI Live de 4 páginas verificados localmente (`20-11-2026`, `ssas/README.md` y `powerbi/evidencias/INDICE.md`).

## Nivel 2 — OLIST 360° (alcance aprobado; implementación pendiente)
- **Aprobación:** `ADR-0002` en estado **`ACEPTADO`** por `mrcastilla8` el `2026-11-26` (PR `#14`, entrada en vigor tras merge a `master`).
- **Alcance:** rediseño de Power BI Live a 15 páginas (8 principales, 4 tooltips, 3 drill-through) sin nuevas medidas DAX, e incorporación de SSRS 2022 Developer Native Mode con 10 informes RDL (`R01`–`R10`) mediante consultas `SELECT` parametrizadas de solo lectura.
- **Ejecución:** 39 tareas individuales organizadas en puertas `G0`–`G4` ([00_PLAN_MAESTRO.md](nivel-2/00_PLAN_MAESTRO.md)) y 29 casos de certificación en [08_PRUEBAS_CERTIFICACION.md](nivel-2/08_PRUEBAS_CERTIFICACION.md).
- **Estado actual:** planificación aprobada; **no está implementado ni certificado todavía** (`NOT_RUN`).

## Futuro, fuera de alcance
Evaluar ML para riesgo logístico; refresh frecuente, Azure/APIs; geolocalización precisa con deduplicación justificada. No añadir scaffolding ni métricas de éxito en bootstrap.
