# Guía individual — Basualdo

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Misión
Revisor semántico de medidas sin editar SSAS. Alcance asignado: **P06, P07, T04, D03; R06, R09**. Rama(s) sugerida(s): `basualdo/nivel-2-analitica`. Leer AGENTS.md raíz, 00, 01, 02, 03, 04, 05, 06, 07, 08 y 09 antes de editar. No abrir PR con trabajo fuera de tu alcance; no añadir DAX, modelo local, cambios SSAS/SSIS/DDL ni datos crudos.

## Tareas implementables
| ID | Tarea | Archivo / entrega | Aceptación |
|---|---|---|---|
| B01 | Verificar baseline SQL/DAX | evidencias y matriz | siete escenarios originales, ocho medidas intactas |
| B02 | P06 | powerbi/entregas/basualdo/ | nota promedio, asociación con puntualidad, sin inferir causa |
| B03 | P07 | entrega individual, powerbi/diseno/cartografia/ | Shape Map con 27 códigos UF y licencia; si bloqueado registrar |
| B04 | T04 y D03 | entrega individual | contexto estado/ciudad, retorno y filtro correcto |
| B05 | R06 | reports/R06_Satisfaccion.rdl, datasets/R06*.sql | notas consolidadas, rangos y NULL correctos |
| B06 | R09 | reports/R09_DesempenoRegional.rdl, datasets/R09*.sql | agregaciones independientes por estado/ciudad/total |
| B07 | Conciliar indicadores | matriz y resultados | igualdad de conteos/importes, ratios tolerancia 1e-7, BLANK/NULL |
| B08 | Revisar entregas del equipo | matriz de revisión | verificar grano, predicados, filtros equivalentes |

## Dependencias y decisiones
Ángel facilita plantilla y recibe páginas; Poma publica RDL; Cueva revisa SQL. No modificar Model.bim ni scripts SSAS; usar Comparar-Metricas.ps1 existente según README.

## Criterios de aceptación
BASE-03, PBI-04/08, SSRS-08/11; validación semántica R01 y restantes. Cada tarea requiere archivo real, ejecución en Windows, evidencia con HEAD y filtro, y registro de limitaciones. Los SQL de 06 son referencias pendientes de ejecución: probar con SSMS y Report Builder, guardar CommandText equivalente y conciliación. Los RDL deben incluir parámetros, origen compartido, no-data, PDF y Excel. Las páginas PBI deben conservar Live, usar solo medidas aprobadas y cumplir retícula e interacciones. Entregar PBIX individual (si aplica), no editar el maestro salvo el custodio.

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
