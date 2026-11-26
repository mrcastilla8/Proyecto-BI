# Guía individual — Poma

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Misión
Responsable del servidor SSRS y publicación. Alcance asignado: **Apoyo P08; R07, R08**. Rama(s) sugerida(s): `poma/nivel-2-reporting`. Leer AGENTS.md raíz, 00, 01, 02, 03, 04, 05, 06, 07, 08 y 09 antes de editar. No abrir PR con trabajo fuera de tu alcance; no añadir DAX, modelo local, cambios SSAS/SSIS/DDL ni datos crudos.

## Tareas implementables
| ID | Tarea | Archivo / entrega | Aceptación |
|---|---|---|---|
| M01 | Inventario e instalación SSRS | reporting-services/README.md y evidencias | Developer Native Mode, catálogo en SQL compatible, portal de humo |
| M02 | Seguridad y origen compartido | datasources/, instrucciones locales | Windows, Browser, identidad SELECT; sin credenciales en Git |
| M03 | Plantilla y proyecto | diseno/, proyecto/ o método Report Builder, manifiesto | G1 aprobado y rutas de 07 |
| M04 | R07 | reports/R07_ImportesPagados.rdl, datasets/R07*.sql | pago observado por pedido, NULL explícito |
| M05 | R08 | reports/R08_FichaPedido.rdl, datasets/R08*.sql | cabecera y detalle separados; ID inexistente y sin ítems |
| M06 | Publicar 10 RDL | portal y manifiesto | 10/10 en carpetas, orígenes resueltos y parámetros |
| M07 | Verificar exportación | matriz y evidencias | 10 PDF + 10 XLSX; sin recortes ni HTML de error |
| M08 | Integración y demo | URLs verificadas, pasos de reproducción | P08 accesible, R05→R08, equipo demo y rollback |

## Dependencias y decisiones
Preflight prioritario G0. Si extensión Visual Studio no compatible, Report Builder es ruta aprobada. No tocar SSIS ingesta, modelo ni datos. Castilla/Cueva revisan consultas, Ángel necesita rutas finales.

## Criterios de aceptación
SSRS-01/02/09/10/14, INT-02/03; registrar ejecución de todos los RDL y permisos. Cada tarea requiere archivo real, ejecución en Windows, evidencia con HEAD y filtro, y registro de limitaciones. Los SQL de 06 son referencias pendientes de ejecución: probar con SSMS y Report Builder, guardar CommandText equivalente y conciliación. Los RDL deben incluir parámetros, origen compartido, no-data, PDF y Excel. Las páginas PBI deben conservar Live, usar solo medidas aprobadas y cumplir retícula e interacciones. Entregar PBIX individual (si aplica), no editar el maestro salvo el custodio.

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
