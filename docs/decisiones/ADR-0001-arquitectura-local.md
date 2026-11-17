# ADR-0001: arquitectura local reproducible con SSAS

- Estado: aceptado como dirección inicial; modelo físico/compatibilidad son propuestas pendientes de validación.
- Fecha: 2026-11-17. Coordinación: Castilla.

## Contexto
Cinco integrantes trabajan desde equipos y redes distintos; no deben depender del SQL Server de un compañero ni sustituir SSIS/SSAS.

## Decisión
Cada quien usa SQL Server local y BI_OLIST, con instancia/puerto/auth locales. Flujo CSV → SSIS → staging → SSIS → DW → SSAS Tabular → Power BI Live. Código se integra por Git; no bases/datos por repositorio. Modelo propuesto usa dos granos del contrato. Python estándar valida fixtures/contratos.

## Consecuencias
Desarrollo no requiere servicio remoto. Integración completa necesita equipo Windows con servicios compatibles y acceso SSAS seguro. Developer es opción académica/no productiva cuando hace falta SSAS; Express no lo incluye, instalar SSAS aparte. Verificar versiones/proveedores reales. Tablas/medidas son propuesta hasta PR/ADR.

## Alternativas fuera de Nivel 1
SQL abierto a internet, ETL cloud, Python/pandas sustituyendo SSIS o Power BI importado sustituyendo SSAS.
