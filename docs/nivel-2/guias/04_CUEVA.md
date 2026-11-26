# Guía individual — Cueva

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Misión
Revisor SQL y granularidad. Alcance asignado: **P04, P05, T03, D02; R03, R05**. Rama(s) sugerida(s): `cueva/nivel-2-operaciones`. Leer AGENTS.md raíz, 00, 01, 02, 03, 04, 05, 06, 07, 08 y 09 antes de editar. No abrir PR con trabajo fuera de tu alcance; no añadir DAX, modelo local, cambios SSAS/SSIS/DDL ni datos crudos.

## Tareas implementables
| ID | Tarea | Archivo / entrega | Aceptación |
|---|---|---|---|
| X01 | P04 | powerbi/entregas/cueva/ | ranking vendedores, cuatro medidas de detalle; filtros EV/Vend |
| X02 | P05 | entrega individual | puntualidad, tiempos, estado de cabecera y flete independiente |
| X03 | T03 y D02 | entrega individual | tooltip logístico y detalle vendedor con retorno |
| X04 | R03 | reports/R03_RankingVendedores.rdl, datasets/R03*.sql | TopN exacto y desempate estable; sin promedio de promedios |
| X05 | R05 | reports/R05_EntregasRetrasadas.rdl, datasets/R05*.sql | día calendario, rango mínimo y acción a R08 |
| X06 | Revisión SQL | matriz de revisión | SELECT parametrizado, no doble conteo, resultados sin datos y totales |
| X07 | Pruebas y entrega | capturas, SQL y matriz | filtros compatibles, fixtures aisladas y evidencia exportable |

## Dependencias y decisiones
Poma entrega plantilla RDL y ruta R08; Ángel integra páginas. Basualdo revisa semántica. No editar SSIS, DDL ni datos; no añadir índices.

## Criterios de aceptación
PBI-05/06, SSRS-05/07, revisión SQL R01–R10. Cada tarea requiere archivo real, ejecución en Windows, evidencia con HEAD y filtro, y registro de limitaciones. Los SQL de 06 son referencias pendientes de ejecución: probar con SSMS y Report Builder, guardar CommandText equivalente y conciliación. Los RDL deben incluir parámetros, origen compartido, no-data, PDF y Excel. Las páginas PBI deben conservar Live, usar solo medidas aprobadas y cumplir retícula e interacciones. Entregar PBIX individual (si aplica), no editar el maestro salvo el custodio.

## Procedimiento Git (PowerShell)
```powershell
git fetch origin
git switch master
git pull --ff-only origin master
# Crear rama indicada tras aprobar G0/G1; si ya existe, actualizarla sin reescritura.
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test_*.py'
git diff --check
git diff --name-only origin/master...HEAD -- ssas ssis database contracts
```
Último comando sin diferencias. Crear PR en español a master, consignar IDs de tareas, evidencia, estado real y dependencias. Revisiones cruzadas según 09. No force-push ni merge con checks pendientes. Reportar BLOCKED con error y reproducción; nunca inventar capturas o resultados.
