# 10 — Demostración integral

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Narrativa
Un gerente de comercio electrónico necesita entender volumen, concentración comercial, experiencia y puntualidad y después investigar pedidos y producir documentación. Mostrar datos históricos, no operación actual ni causalidad.

| Orden | Responsable | Acción | Evidencia que debe verse |
|---|---|---|---|
| 1 | Castilla | P01: ocho KPI, propósito, flujo SSIS→DW→SSAS/SSRS | Live y cifras reales |
| 2 | Ángel | P02, P03: seleccionar 2017, categoría y drill-through producto | cambio de contexto y retorno |
| 3 | Cueva | P04, P05: vendedor y cumplimiento regional | solo medidas compatibles; región crítica real seleccionada antes |
| 4 | Basualdo | P06, P07: satisfacción, mapa, estado/ciudad | no afirmar causalidad; mostrar patrón |
| 5 | Poma | P08/R05: abrir informe, fijar mismos parámetros manualmente, elegir retrasado y R08 | portal, drill-through y ficha |
| 6 | Poma | exportar R05 o R08 PDF y Excel, abrir ambos | formato y datos utilizables |
| 7 | Castilla | R01 y R10, conciliación y cierre | misma semántica, auditoría sin datos sensibles |

## Preparación
Identificar con consultas reales un estado con suficientes pedidos y retrasos, un OrderId válido con líneas y un período histórico (preferencia 2017 por cobertura); registrar filtros y resultados. No fijar un pedido inventado. Verificar conexión Live, servicios SSAS/SSRS, cuenta Browser, portal, URLs y PDF/XLSX. Cerrar notificaciones, ocultar rutas personales, usar 16:9 y escala de proyector. Mantener copia del PBIX y RDL aprobados y evidencia local offline como contingencia, pero distinguir evidencia de ejecución en vivo. Si falla servicio, mostrar error y contingencia, no simular éxito.

## Mensaje final
Power BI facilita explorar y decidir; SSRS permite investigar, parametrizar y distribuir informes imprimibles. Ambos consumen el mismo DW, las ocho medidas originales se mantienen y los resultados se concilian. No se requiere nube ni licencia productiva. Ensayar en equipo demo y ajustar duración a tiempo asignado por docente; no inventar una duración obligatoria.
