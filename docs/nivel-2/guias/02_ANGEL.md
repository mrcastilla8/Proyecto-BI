# Guía individual — Ángel

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Misión
Custodia exclusiva del PBIX maestro. Alcance asignado: **P02, P03, T01, T02, D01; R02, R04**. Rama(s) sugerida(s): `angel/nivel-2-powerbi; angel/nivel-2-pbix-maestro`. Leer AGENTS.md raíz, 00, 01, 02, 03, 04, 05, 06, 07, 08 y 09 antes de editar. No abrir PR con trabajo fuera de tu alcance; no añadir DAX, modelo local, cambios SSAS/SSIS/DDL ni datos crudos.

## Tareas implementables
| ID | Tarea | Archivo / entrega | Aceptación |
|---|---|---|---|
| A01 | Implementar tema y plantilla con Castilla | powerbi/themes/olist360.json, diseno/ | tema importado, 16:9, menú y panel reutilizable |
| A02 | P02 | powerbi/entregas/angel/ | series mensuales, matriz calor y día de semana, sin cálculo adicional |
| A03 | P03 | entrega individual | barras, treemap y matriz; cuatro medidas de detalle |
| A04 | T01, T02, D01 | entrega individual | contexto correcto, drill-through producto y retorno |
| A05 | R02 | reports/R02_ConsolidadoMensual.rdl, datasets/R02*.sql | mensual y total independiente |
| A06 | R04 | reports/R04_RendimientoCategorias.rdl, datasets/R04*.sql | subtotales recalculados por categoría/producto |
| A07 | Integrar 15 páginas | powerbi/BI_OLIST.pbix | 8 visibles, 7 ocultas, conexión Live y navegación reconstruida |
| A08 | Certificar visual y rendimiento | powerbi/validacion/, evidencias/ | capturas 15, Performance Analyzer, matriz e interacciones |

## Dependencias y decisiones
Esperar plantilla aprobada G1 y entregas de Castilla, Cueva y Basualdo para A07. No editar PBIX maestro durante integración de otros autores; tú eres el único escritor. Poma entrega URLs, Basualdo concilia.

## Criterios de aceptación
PBI-01/02/03/07/09, SSRS-04/06; exportaciones propias para revisión de Poma. Cada tarea requiere archivo real, ejecución en Windows, evidencia con HEAD y filtro, y registro de limitaciones. Los SQL de 06 son referencias pendientes de ejecución: probar con SSMS y Report Builder, guardar CommandText equivalente y conciliación. Los RDL deben incluir parámetros, origen compartido, no-data, PDF y Excel. Las páginas PBI deben conservar Live, usar solo medidas aprobadas y cumplir retícula e interacciones. Entregar PBIX individual (si aplica), no editar el maestro salvo el custodio.

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
