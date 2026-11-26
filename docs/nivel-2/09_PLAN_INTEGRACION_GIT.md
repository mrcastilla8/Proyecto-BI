# 09 — Integración Git y control de cambios

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Reglas
Leer AGENTS.md y AGENTS por componente. Ramas apellido/implementacion ASCII kebab-case, commits y PR en español, master como destino. No force-push, no secretos/CSV/backups ni rutas personales. No modificar contratos, modelo ni pipelines. Verificar HEAD actual y cambios posteriores al snapshot antes de iniciar. Los siguientes comandos son PowerShell y requieren repo clonado, working tree limpio.
```powershell
git status --short
git fetch origin
git switch master
git pull --ff-only origin master
git switch -c castilla/nivel-2-plan
```
Castilla incorpora `docs/nivel-2/`, ADR y actualizaciones normativas en PR inicial; no abrir desarrollo antes de G0/G1 aprobados. Tras merge, cada integrante crea rama desde master actualizado.

| Rama sugerida | Propietario | Archivos |
|---|---|---|
| castilla/nivel-2-plan | Castilla | docs/ y reglas |
| castilla/nivel-2-integracion | Castilla | páginas individuales P01/P08, R01/R10 |
| angel/nivel-2-powerbi | Ángel | tema aprobado, P02/P03 y R02/R04 |
| basualdo/nivel-2-analitica | Basualdo | P06/P07, R06/R09 y conciliación |
| cueva/nivel-2-operaciones | Cueva | P04/P05, R03/R05 y revisión SQL |
| poma/nivel-2-reporting | Poma | R07/R08, proyecto y configuración |
| angel/nivel-2-pbix-maestro | Ángel | PBIX maestro e integración final |

## PBIX: un único escritor
No intentar merge binario. Castilla aprueba plantilla base con menú/tema; cada responsable copia a archivo de trabajo `powerbi/entregas/<apellido>/...pbix` o entrega fuera de Git si tamaño/privacidad lo exige, con hash y evidencia. Nunca editar el PBIX maestro salvo Ángel. Integración manual copiando visuales/páginas según Desktop; reconstruir marcadores, navegación, sync slicers, tooltip y drill-through si se pierden. Mantener versiones individuales hasta aceptación; no publicar archivos con datos importados. El único entregable final es `powerbi/BI_OLIST.pbix`.

## RDL: trabajo paralelo
Un archivo RDL y SQL por dataset/informe, sin tocar proyecto compartido de otro. Poma crea plantilla y mantiene manifiesto/proyecto, revisa conexión compartida y publica. Cada autor entrega archivos con ID exacto; Cueva revisa SQL y Basualdo semántica, revisiones cruzadas (R01/R10 revisados por Basualdo o Poma). Castilla revisa Poma. Cambios normativos solo Castilla.

## Gates del PR
```powershell
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test_*.py'
git diff --check
git diff --name-only origin/master...HEAD -- ssas ssis database contracts
```
Último comando sin archivos modificados en alcance congelado. Documentar prueba Windows real, no reemplazar por validación Python. PR describe tarea, archivos, resultados, evidencia, limitaciones. No merge con checks obligatorios fallidos o conversaciones pendientes. Revalidar tras actualizar rama. Integración de portal y PBIX requiere prueba final en mismo equipo. Si conflicto en RDL, autor resuelve; PBIX recuperar versión única, no combinar por bytes.
