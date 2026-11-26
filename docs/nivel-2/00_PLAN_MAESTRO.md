# 00 — Plan maestro de BI-OLIST Nivel 2

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## 1. Mandato y línea base
El profesor solicita pulir Power BI y aplicar Microsoft Reporting Services. El producto se denomina **OLIST 360° — Business Intelligence Suite**. La calidad se evalúa por decisiones soportadas, claridad visual, experiencia de navegación, exactitud semántica, informes utilizables y reproducibilidad; no por cantidad de gráficos.

Repositorio: `mrcastilla8/Proyecto-BI`, `master` auditada en `d96789ef7f17f3c36b366965ffde976daf0eec19`. Antes de trabajar, registrar el HEAD efectivo y comprobar cambios posteriores. El PBIX existente tiene cuatro páginas Live y las capturas REP-02 a REP-05 muestran diseño predeterminado, etiquetas técnicas, filtros grandes y poca jerarquía. Se conserva como punto de partida, no se desecha.

## 2. Decisiones vinculantes
- Exactamente las ocho medidas originales; prohibidas nuevas medidas DAX incluso locales, visual calculations, columnas calculadas, tablas locales, modelo compuesto o importación de datos para suplir SSAS. Se permiten consultas DAX de comprobación de las medidas existentes (no cambios al modelo).
- Congelar `ssas/BI_OLIST_Tabular/Model.bim`, proyectos SSIS, DDL de `database/` y contratos v1. No crear vistas, procedimientos, índices o tablas nuevas en BI_OLIST. Configurar permisos de lectura local es admisible, no alterar datos. SQL SELECT parametrizado en Reporting Services sí; cálculos exclusivos de informe no se presentan como medidas DAX nuevas.
- Power BI Desktop Live a `BI_OLIST_Tabular`; ocho páginas visibles, cuatro tooltips y tres páginas de drill-through. No publicar PBIX en SSRS: SSRS aloja RDL; Power BI se ejecuta en Desktop.
- SSRS 2022 Developer, modo nativo, uso académico; motor SQL Server 2025 Developer existente. Diez RDL publicados y exportables. Sin dependencia de nube, correo, cuentas de pago ni acceso público.
- Integración mediante URL fija a cada RDL y selección explícita de parámetros en SSRS. Drill-through RDL→RDL parametrizado. No prometer transferencia de filtros de Power BI.
- Datos históricos Olist; BRL nominales. No margen, utilidad, pronóstico, RFM, cohortes, métodos de pago, ni satisfacción por producto/vendedor. R07 solo importes agregados por pedido.

## 3. Entregables y propietarios
| Responsable | Power BI | RDL | Transversal |
|---|---|---|---|
| Castilla | P01 P08 | R01 R10 | ADR, arquitectura, sistema visual, integración, certificación |
| Ángel | P02 P03 T01 T02 D01 | R02 R04 | Custodio único del PBIX maestro |
| Basualdo | P06 P07 T04 D03 | R06 R09 | Conciliación y revisión semántica |
| Cueva | P04 P05 T03 D02 | R03 R05 | Revisión de SQL y granularidad |
| Poma | Prueba de integración P08 | R07 R08 | Infraestructura SSRS, proyecto, portal, despliegue, exportación |

## 4. Hitos y puertas de integración
| Puerta | Entrega obligatoria | Bloquea |
|---|---|---|
| G0 | ADR aprobado, HEAD base, inventario Windows y prueba Live, instalación SSRS y portal de prueba | Desarrollo integrado |
| G1 | Tema, plantilla PBIX, plantilla RDL, contrato de nombres de parámetros y rutas portal | Trabajo paralelo |
| G2 | 8 páginas + 7 auxiliares en entregas individuales; 10 RDL y SQL verificables | Integración |
| G3 | PBIX maestro Live, portal 10/10, accesos cruzados, exportaciones | Certificación |
| G4 | Matriz de pruebas, resultados reales, regresión, demo ensayada y PRs integrados | Cierre |
No fijar fechas sin acuerdo del equipo. G0/G1 son prioridad; RDL y páginas avanzan en paralelo después del contrato común.

## 5. Evidencia histórica de referencia
1.550.922 filas de ingesta aceptadas; 99.441 pedidos y 112.650 líneas. Ocho KPI históricos: ventas R$ 13.221.498,11; pedidos con ítems entregados 96.478; pedidos totales 99.441; ticket R$ 137,04; flete R$ 2.198.275,64; puntualidad 93,23 %; duración 12,56 días; calificación 4,09/5. Fuente: `ssas/README.md` y `powerbi/README.md`, evidencia 20/11/2026. No extrapolar a una carga diferente ni convertir redondeos en resultados exactos.

## 6. Cierre
Criterios detallados en `08_PRUEBAS_CERTIFICACION.md`. No declarar PASS sin archivos y ejecución real. Un bloqueo se reporta como BLOCKED con error, reproducción, responsable y alternativa, no como éxito. La instalación, mapa, diseño y ejecución de Nivel 2 aún no están verificados. El alcance se formaliza con ADR y actualización normativa (ver 01 y 09); este paquete no cambia el repositorio por sí mismo.
