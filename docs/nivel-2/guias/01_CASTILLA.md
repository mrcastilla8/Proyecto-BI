# Guía individual — Castilla

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Misión
Arquitectura, contratos, diseño y certificación. Alcance asignado: **P01, P08; R01, R10**. Rama(s) sugerida(s): `castilla/nivel-2-plan; castilla/nivel-2-integracion`. Leer AGENTS.md raíz, 00, 01, 02, 03, 04, 05, 06, 07, 08 y 09 antes de editar. No abrir PR con trabajo fuera de tu alcance; no añadir DAX, modelo local, cambios SSAS/SSIS/DDL ni datos crudos.

## Tareas implementables
| ID | Tarea | Archivo / entrega | Aceptación |
|---|---|---|---|
| C01 | Formalizar alcance y ADR | docs/nivel-2/, ADR-0002, docs/AGENTS actualizados | Nivel 2 aprobado; contratos y componentes congelados |
| C02 | Aprobar plantilla común y tema con Ángel/Poma | powerbi/diseno/, reporting-services/diseno/ | G1: retícula, paleta y RDL de muestra validados |
| C03 | Implementar P01 | powerbi/entregas/castilla/ | ocho KPI, línea mensual, top categoría, comparación pedidos sin fuga de contexto |
| C04 | Implementar P08 | entrega individual | diez accesos reales y nota de filtros independientes |
| C05 | R01 | reports/R01_ResumenGerencial.rdl, datasets/R01*.sql | dos datasets independientes; ocho métricas conciliadas |
| C06 | R10 | reports/R10_AuditoriaETL.rdl, datasets/R10*.sql | lotes, conciliación, privacidad y reintentos |
| C07 | Coordinar integración | matriz y manifiesto | Ángel integra PBIX, Poma publica; probar rutas y filtros |
| C08 | Certificar cierre | matriz de pruebas, informe y demo | G4 sin regresiones y evidencia real |

## Dependencias y decisiones
Tras el merge del PR documental `#14`, se crean los issues y ramas individuales desde `master` actualizado. Poma ejecuta `M01`–`M02` para `G0`; Castilla, Ángel y Poma ejecutan las actividades preparatorias de `G1` (`C02`, `A01`, `M03`). El desarrollo funcional paralelo de páginas e informes definitivos comienza tras superar `G1`. Basualdo verifica ocho KPI; Cueva revisa SQL. No asumir aprobación del ADR ni marcar PASS por mera documentación.

## Criterios de aceptación
BASE-01/02, SSRS-03/12, INT-01/03; validar C01–C08. Cada tarea requiere archivo real, ejecución en Windows, evidencia con HEAD y filtro, y registro de limitaciones. Los SQL de 06 son referencias pendientes de ejecución: probar con SSMS y Report Builder, guardar CommandText equivalente y conciliación. Los RDL deben incluir parámetros, origen compartido, no-data, PDF y Excel. Las páginas PBI deben conservar Live, usar solo medidas aprobadas y cumplir retícula e interacciones. Entregar PBIX individual (si aplica), no editar el maestro salvo el custodio.

## Procedimiento Git (PowerShell)
```powershell
git fetch origin
git switch master
git pull --ff-only origin master
# Crear la rama asignada desde master actualizado tras el merge del PR #14; desarrollar páginas e informes definitivos tras aprobar G1.
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test_*.py'
git diff --check
git diff --name-only origin/master...HEAD -- ssas ssis database contracts
```
Último comando sin diferencias. Crear PR en español a master, consignar IDs de tareas, evidencia, estado real y dependencias. Revisiones cruzadas según 09. No force-push ni merge con checks pendientes. Reportar BLOCKED con error y reproducción; nunca inventar capturas o resultados.
