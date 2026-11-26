# Manual operativo para agentes

## Misión y fuentes de verdad
Construye BI-OLIST Nivel 1 según README, docs/contexto-y-alcance.md y docs/arquitectura.md. Antes de editar, lee issue asignado, ambos contratos en contracts/, ADR aplicable y AGENTS.md del componente. Precedencia: alcance vinculante, ADR aprobado, contrato versionado, issue aprobado, documentación del componente. Contradicción requiere propuesta y revisión de dependientes; nunca cambies semántica silenciosamente.

## Flujo y responsables
CSV Olist → SSIS → SQL Server BI_OLIST (stg/dw/audit) → SSAS Tabular → Power BI Live. Python estándar solo valida documentación, contratos y fixtures. ML, nube, APIs y tiempo real quedan fuera.
- Castilla @mrcastilla8: arquitectura, contratos, SQL dimensional, integración/informe; castilla/modelo-dimensional.
- Poma @GabrielPGu: SSIS CSV a staging; poma/ssis-ingesta.
- Cueva @AXL031: SSIS staging a DW; cueva/ssis-transformaciones.
- Basualdo @MarcosBasualdoAle: SSAS Tabular y DAX; basualdo/ssas-tabular.
- Ángel @luisdem01: Power BI; angel/powerbi-reportes.

## Git, seguridad y ejecución
Ramas apellido/implementación, ASCII minúsculas kebab-case; master única excepción. No crear main, feat/*, fix/* ni codex/*. Commits/PR en español. Todo cambio va por PR a master y requiere checks obligatorios verdes y conversaciones resueltas; no exige aprobación humana externa. Las revisiones son voluntarias. CODEOWNERS sugiere revisores, no concede permisos por carpeta. No force-push ni reescritura.

No subir CSV/ZIP real, backups, datos sensibles o secretos. No descargar con credenciales ajenas. No fijar rutas personales, host, puerto o credenciales en fuentes; parametrizar localmente. Nunca exponer SQL/SSAS a internet. Fixtures identificadas como sintéticas.

Para cada tarea: lee issue, contratos y ADR; confirma rutas; propone ADR/issue antes de cambiar grano o métricas; implementa solo componente asignado; documenta errores/reintentos/idempotencia; ejecuta `python scripts/validar_base.py` y prueba Windows de componente; registra comandos, resultado real y limitaciones. Linux ejecuta solo validación Python/fixtures; no SSIS, SQL Server, SSAS ni Power BI. Reporta bloqueos con error exacto, entorno y reproducción. Terminado requiere aceptación, evidencia real, verificación cruzada, CI y documentación.

## Ampliación Nivel 2 — OLIST 360° (pendiente de aprobación)
La especificación del Nivel 2 reside en `docs/nivel-2/` y `docs/decisiones/ADR-0002-nivel-2-powerbi-reporting-services.md`. Amplía exclusivamente la capa de consumo: Power BI Desktop Live (15 páginas: 8 principales, 4 tooltips y 3 drill-through) y SSRS 2022 Developer Native Mode (10 informes RDL mediante consultas `SELECT` parametrizadas de solo lectura). Permanecen congelados `database/`, `contracts/`, `ssis/`, `ssas/` y las ocho medidas DAX originales (prohibido agregar medidas DAX locales, columnas calculadas o modo Import). Ángel es el custodio único de `powerbi/BI_OLIST.pbix` durante la integración. La integración Power BI → SSRS usa URLs fijas y parametrización dentro del portal SSRS. No iniciar desarrollo funcional ni instalar SSRS antes de aprobar el PR de formalización y superar las puertas `G0`/`G1`.
