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

Para cada tarea: lee issue, contratos y ADR; confirma rutas; propone ADR/issue antes de cambiar grano o métricas; implementa solo componente asignado; documenta errores/reintentos/idempotencia; ejecuta `python scripts/validar_base.py` y prueba Windows de componente; registra comandos, resultado real y limitaciones. Linux ejecuta solo validación Python/fixtures; no SSIS, SQL Server, SSAS ni Power BI. Reporta bloqueos con error exacto, entorno y reproducción. Terminado requiere aceptación, evidencia real, revisión ajena, CI y documentación.
