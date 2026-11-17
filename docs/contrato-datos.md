# Contrato de datos v1

`contracts/modelo-dimensional.v1.json` es propuesta versionada, no DDL implementado. Define fuentes, granos, claves, dimensiones, relaciones y reglas. Tablas/columnas definitivas se aprueban por PR y ADR antes de implementación. Decisión sin soporte: marcar `PROPUESTA_PENDIENTE_VALIDACION`.

Pagos múltiples se agregan por pedido antes de FactPedidos; reviews múltiples se consolidan una vez por pedido (media válida propuesta), sin multiplicar líneas. Nunca unir hechos con detalle de pagos/reviews crudo. `customer_unique_id` y `customer_id` son conceptos distintos. Geografías cliente/vendedor ocupan roles separados. No relacionar geolocation por prefijo postal sin justificación de deduplicación. DECIMAL para dinero, fechas DATETIME2/DATE, controles de duplicados y desconocido explícito. Cambios requieren issue, impacto en SSIS/SQL/SSAS/Power BI, aprobación de dependientes y ADR. Valida con `python scripts/validar_base.py`.
