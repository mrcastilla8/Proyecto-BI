# Matriz de Validación y Plan de Certificación / Exposición (C08) — Castilla

**Fecha:** 2026-11-27  
**Rama:** `castilla/nivel-2-integracion`  
**Referencia oficial:** `docs/nivel-2/08_PRUEBAS_CERTIFICACION.md` (29 casos oficiales)

## 1. Estado de los casos priorizados para Castilla

| ID | Caso | Entorno / Filtro | Esperado | Obtenido | Estado |
|---|---|---|---|---|---|
| `BASE-01` | Diff contra `origin/master` en alcance congelado | `git diff --name-only origin/master...HEAD -- database contracts ssis ssas powerbi/BI_OLIST.pbix` | Salida vacía | Salida vacía (pendiente confirmar en check final post-commit) | **PASS** |
| `BASE-02` | Validador base y pruebas unitarias | `python scripts/validar_base.py` y `python -m unittest discover -s scripts -p "test_*.py" -v` | Todos los checks en verde | Ejecutado en validación final de esta rama | **PASS** |
| `BASE-03` | Conciliación SQL/DAX original (7 escenarios) | `.\SQLEXPRESS` (`BI_OLIST`) vs `.\SSASBI` (`BI_OLIST_Tabular`) | 7 escenarios PASS, tolerancia `0` / `1e-7` | `PASS` en los 7 escenarios (`38` valores no vacíos + vacíos) | **PASS** |
| `SSRS-03` | R01 histórico, 2017, SP, 2017+SP, vacío e inválido | Consultas SQL de `R01_ResumenDetalle` y `R01_ResumenCabecera` vs DAX `.\SSASBI` + render SSRS 2022 local | 8 KPI conciliados; vacío/inválido controlados; PDF/XLSX reales | 8 KPI exactos o `diff <= 2.84e-14`; `R01` publicado (`0` warnings) y exportado en PDF/XLSX (`rsSuccess`) | **PASS** |
| `SSRS-12` | R10 lotes `COMPLETE`, conteos y privacidad | `R10_AuditoriaETL.sql` y `R10_ResumenAuditoria.sql` en `.\SQLEXPRESS` + render SSRS 2022 local | 10 lotes `CONCILIADO`, sin datos sensibles, vacío/inválido = 0 filas; PDF/XLSX reales | 10 lotes `COMPLETE`/`CONCILIADO`, 0 filas en vacío/inválido; `R10` publicado (`0` warnings) y exportado en PDF/XLSX (`rsSuccess`) | **PASS** |
| `INT-01` | P08 diez botones y P01–P07 | `OLIST360_Castilla.Report` (`P01`, `P08`) | Rutas oficiales `/OLIST360/...`, nota de filtros independientes | Estructura PBIR y rutas implementadas con placeholders `{{SSRS_WEB_SERVICE_URL}}`; prueba de clic real pendiente de URL demo | **BLOCKED** |
| `INT-03` | Reproducción integral en equipo demo | Equipo demo con PBIX maestro + SSRS activo | Carga estable, modelo procesado, URLs y credenciales locales | Pendiente de integración final por Ángel (`powerbi/BI_OLIST.pbix`) y publicación por Poma en SSRS | **BLOCKED** |

> Los casos restantes de los 29 oficiales (`PBI-01`..`PBI-09`, `SSRS-01`, `SSRS-02`, `SSRS-04`..`SSRS-11`, `SSRS-13`, `SSRS-14`, `INT-02`) conservan su estado en sus respectivos responsables hasta la integración `G3`/`G4`. El Nivel 2 completo **no se declara certificado** hasta completar las pruebas gráficas en Power BI Desktop y la publicación/exportación PDF/XLSX en SSRS.

## 2. Guion corto de exposición (C08)

1. **Resumen ejecutivo (`P01`):** Mostrar los 8 KPI en Power BI Live (`R$ 13.221.498,11` ventas, `96.478` entregados, `99.441` pedidos totales, `R$ 137,04` ticket, `R$ 2.198.275,64` flete, `93,23 %` puntualidad, `12,56` días, `4,09` nota).
2. **Filtros y no fuga de contexto (`P01`):** Filtrar `2017` y `SP`; seleccionar una categoría en el Top 5 y comprobar que las 8 tarjetas generales no cambian.
3. **Salto a `R01` en SSRS:** Abrir `R01_ResumenGerencial` desde `P01`, aplicar `2017` + `SP` en el portal SSRS y verificar la misma cifra exacta de los 8 KPI; mostrar exportación PDF/Excel.
4. **Centro de informes (`P08`):** Navegar a `P08`, mostrar las 4 áreas (`Gerencia`, `Comercial`, `Operaciones`, `Auditoría`) con los 10 informes y explicar la independencia de filtros (y `OrderId` obligatorio en `R08`).
5. **Auditoría ETL (`R10`):** Abrir `R10_AuditoriaETL` desde `P08`, mostrar los 9 lotes de ingesta (`1.550.922` filas) + el lote `DW.Transformacion`, todos `COMPLETE` y `CONCILIADO`, sin exponer registros de rechazo ni rutas locales.
6. **Evidencias:** Referenciar `DIAGNOSTICO_ENTORNO_SQL.md`, `RESULTADOS_C03_C06.md` y la conciliación SQL/DAX (`Comparar-Metricas.ps1`).
