# Manual operativo para agentes

## Misión y fuentes de verdad
Construye BI-OLIST Nivel 1 según README, docs/contexto-y-alcance.md y docs/arquitectura.md. Antes de editar, lee issue asignado, ambos contratos en contracts/, ADR aplicable y AGENTS.md del componente. Precedencia: alcance vinculante, ADR aprobado, contrato versionado, issue aprobado, documentación del componente. Contradicción requiere propuesta y revisión de dependientes; nunca cambies semántica silenciosamente.

## Flujo y responsables

### Nivel 1 (línea base congelada)
CSV Olist → SSIS → SQL Server BI_OLIST (stg/dw/audit) → SSAS Tabular → Power BI Live. Python estándar solo valida documentación, contratos y fixtures. ML, nube, APIs y tiempo real quedan fuera.
- Castilla `@mrcastilla8`: arquitectura, contratos, SQL dimensional, integración/informe; `castilla/modelo-dimensional`.
- Poma `@GabrielPGu`: SSIS CSV a staging; `poma/ssis-ingesta`.
- Cueva `@AXL031`: SSIS staging a DW; `cueva/ssis-transformaciones`.
- Basualdo `@MarcosBasualdoAle`: SSAS Tabular y DAX; `basualdo/ssas-tabular`.
- Ángel `@luisdem01`: Power BI; `angel/powerbi-reportes`.

### Nivel 2 — OLIST 360° (ampliación de capa de consumo)
| Responsable | Power BI | RDL | Transversal |
|---|---|---|---|
| Castilla | P01, P08 | R01, R10 | Arquitectura, diseño e integración |
| Ángel | P02, P03, T01, T02, D01 | R02, R04 | Custodio exclusivo del PBIX maestro |
| Basualdo | P06, P07, T04, D03 | R06, R09 | Conciliación semántica |
| Cueva | P04, P05, T03, D02 | R03, R05 | Revisión SQL |
| Poma | Apoyo P08 | R07, R08 | Infraestructura, publicación y exportación SSRS |

## Git, seguridad y ejecución
Ramas apellido/implementación, ASCII minúsculas kebab-case; master única excepción. No crear main, feat/*, fix/* ni codex/*. Commits/PR en español. Todo cambio va por PR a master y requiere checks obligatorios verdes y conversaciones resueltas; no exige aprobación humana externa. Las revisiones son voluntarias. CODEOWNERS sugiere revisores, no concede permisos por carpeta. No force-push ni reescritura.

No subir CSV/ZIP real, backups, datos sensibles o secretos. No descargar con credenciales ajenas. No fijar rutas personales, host, puerto o credenciales en fuentes; parametrizar localmente. Nunca exponer SQL/SSAS a internet. Fixtures identificadas como sintéticas.

Para cada tarea: lee issue, contratos y ADR; confirma rutas; propone ADR/issue antes de cambiar grano o métricas; implementa solo componente asignado; documenta errores/reintentos/idempotencia; ejecuta `python scripts/validar_base.py` y prueba Windows de componente; registra comandos, resultado real y limitaciones. Linux ejecuta solo validación Python/fixtures; no SSIS, SQL Server, SSAS ni Power BI. Reporta bloqueos con error exacto, entorno y reproducción. Terminado requiere aceptación, evidencia real, verificación cruzada, CI y documentación.

## Ampliación Nivel 2 — OLIST 360° (alcance aprobado; implementación pendiente)
La especificación del Nivel 2 reside en `docs/nivel-2/` y `docs/decisiones/ADR-0002-nivel-2-powerbi-reporting-services.md` (estado **`ACEPTADO`** por `mrcastilla8` el `2026-11-26` en el PR `#14` como alcance arquitectónico y documental; entra en vigor tras el merge a `master`, permaneciendo pendientes su implementación y certificación práctica). Amplía exclusivamente la capa de consumo: Power BI Desktop Live (15 páginas: 8 principales, 4 tooltips y 3 drill-through) y SSRS 2022 Developer Native Mode (10 informes RDL mediante consultas `SELECT` parametrizadas de solo lectura). Permanecen congelados `database/`, `contracts/`, `ssis/`, `ssas/` y las ocho medidas DAX originales (prohibido agregar medidas DAX locales, columnas calculadas o modo Import). Ángel es el custodio único de `powerbi/BI_OLIST.pbix` durante la integración. La integración Power BI → SSRS usa URLs fijas y parametrización dentro del portal SSRS.

Secuencia vinculante tras la aprobación y merge del PR documental `#14`:
1. Creación de los issues y ramas individuales desde `master` actualizado.
2. **G0 (preflight):** instalación de SSRS, catálogo, portal, autenticación Windows, origen compartido, prueba de humo (portal + PDF/XLSX) y conexión Live a SSAS (Poma ejecuta `M01`–`M02` tras el merge documental; no se exigen los 10 RDL definitivos para `G0`).
3. **G1 (plantillas):** construcción y aprobación de las plantillas comunes de Power BI y RDL (Castilla, Ángel y Poma ejecutan las actividades preparatorias `C02`, `A01`, `M03`).
4. **G2 (desarrollo paralelo):** comienza **después de superar G1**; desarrollo de páginas e informes definitivos.
5. **G3 (integración)** y **G4 (certificación)** sobre los 29 casos definidos en `docs/nivel-2/08_PRUEBAS_CERTIFICACION.md`.

No exigir superar una puerta para comenzar las tareas necesarias para satisfacer esa misma puerta.
