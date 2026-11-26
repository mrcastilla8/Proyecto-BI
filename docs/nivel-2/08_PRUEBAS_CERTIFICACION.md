# 08 — Plan de pruebas y certificación

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Convención
Estado inicial NOT_RUN. PASS requiere fecha, HEAD, entorno, filtro, esperado, obtenido, evidencia y responsable. FAIL si difiere; BLOCKED si falta prerrequisito, con reproducción. No marcar un objetivo como resultado. Usar `powerbi/validacion/matriz.csv` y `reporting-services/validacion/matriz.csv` con columnas `id,componente,head,entorno,precondicion,entrada,esperado,obtenido,estado,evidencia,responsable`. No subir datos crudos.

| ID | Caso | Esperado | Responsable |
|---|---|---|---|
| BASE-01 | diff contra HEAD aprobado | Model.bim, SSIS, database, contracts sin cambios | Castilla |
| BASE-02 | validador y unittest | python scripts/validar_base.py y python -m unittest discover -s scripts -p 'test_*.py' pasan | Castilla |
| BASE-03 | comparar SQL/DAX original | 7 escenarios históricos reproducidos, contexto correcto | Basualdo |
| PBI-01 | abrir PBIX en Desktop | Live conectado, 8 medidas originales, sin modelo local | Ángel |
| PBI-02 | 8 páginas visibles | 8/8, sin clipping, textos legibles, tema coherente | Ángel |
| PBI-03 | 7 auxiliares | 4 tooltips, 3 drill-through con contexto y retorno | Ángel |
| PBI-04 | año 2017 + EC SP | sincronización P01–P07, coincide SQL/SSAS | Basualdo |
| PBI-05 | categoría y vendedor | solo medidas de detalle, no fuga de filtros | Cueva |
| PBI-06 | estado cancelado | P filtrado, C/D sin elegibles, F independiente | Cueva |
| PBI-07 | abrir/cerrar panel | filtros preservados; reset restaura defaults | Ángel |
| PBI-08 | mapa | 27 claves únicas cartográficas, estados con datos asociados correctamente, sin geocodificación errónea | Basualdo |
| PBI-09 | vacío, ID largo, meses parciales | mensajes correctos, etiquetas legibles | Ángel |
| SSRS-01 | versión/catálogo/portal | modo nativo, instancia soportada, 10 informes publicados | Poma |
| SSRS-02 | seguridad | Browser lectura, no publicación; no autorizado rechazado; identidad DW sin DML | Poma |
| SSRS-03 | R01 histórico y SP | ocho KPI equivalentes a SQL/DAX con mismo filtro | Castilla |
| SSRS-04 | R02 año/mes/categoría | totales recalculados, orden temporal | Ángel |
| SSRS-05 | R03 Top 10/20/50 y empate | límite exacto, desempate estable | Cueva |
| SSRS-06 | R04 pedido en múltiples productos | distintos correctos por nivel | Ángel |
| SSRS-07 | R05 retraso 0/1 y rango | mismo día excluido, día siguiente incluido | Cueva |
| SSRS-08 | R06 decimal y NULL | nota consolidada única, rangos correctos | Basualdo |
| SSRS-09 | R07 multilínea y sin pago | pago una vez, NULL no cero | Poma |
| SSRS-10 | R08 válido, inexistente y sin ítems | cabecera/detalle separados; mensaje correcto | Poma |
| SSRS-11 | R09 estado/ciudad/total | cada hecho agregado antes de unir, sin doble conteo | Basualdo |
| SSRS-12 | R10 lote COMPLETE, fallido fixture | estados y conteos correctos; no datos sensibles | Castilla |
| SSRS-13 | todos: límites y sin datos | guardas, parámetro inválido, no error SQL visible | Cada autor |
| SSRS-14 | PDF/XLSX 10/10 | abre, sin recorte/página blanca, datos numéricos utilizables | Poma |
| INT-01 | P08 diez botones y P01–P07 | rutas correctas, portal autenticado, filtros no transferidos | Castilla |
| INT-02 | R05→R08 y otras acciones | OrderId y parámetros preservados cuando aplican | Poma |
| INT-03 | reproducción en equipo demo | carga estable, modelo procesado, URLs y credenciales locales | Castilla |

## Conciliación
Baseline: ocho KPI de `ssas/README.md` (redondeados para presentación). Comparar valores no redondeados mediante `ssas/validacion/Comparar-Metricas.ps1`, SQL de RDL y capturas PBI/SSRS en contextos idénticos. Conteos e importes exactos; ratios 1e-7; comparar BLANK/NULL explícitamente. Escenarios mínimos total con fecha conocida, 2017, SP, 2017+SP, categoría concreta (solo detalle), vendedor/EV (solo detalle), cancelado (cabecera), rango vacío. R06 sin filtro de nota y R09 total concilian con S; R07/R05 exclusivos SQL se validan con segunda consulta independiente. Usar fixtures aisladas para casos extremos; nunca insertar datos artificiales en la base demo.

## Rendimiento reproducible
Objetivos (no medidos): PBI carga inicial ≤8 s, interacción ≤3 s; RDL habitual ≤5 s, exportación ≤15 s. Perfil habitual = fechas 2017, región SP, R03 Top10, R05 mínimo 1; R08 pedido conocido; R10 período de lotes verificado. Si exportación masiva supera objetivo, medir separado y documentar volumen; no ocultar filas. Registrar equipo CPU/RAM, versiones, filas retornadas, contexto, timestamp. 1 corrida fría (reiniciar cliente, declarar caché servidor no controlada si aplica), 5 calientes; reportar mediana y máximo, sin descartar fallos. PBI Performance Analyzer para visuales y cronómetro para tiempo de página/interacción; SSRS ExecutionLog3 si autorizado o cronómetro + HTTP. Objetivos aplican mediana caliente; registrar frío y máximo aparte. Si no cumple, optimizar visuales/consultas SELECT sin alterar modelo, repetir; no cambiar umbrales sin aprobación. Fuente: https://learn.microsoft.com/power-bi/create-reports/desktop-performance-analyzer .

## Cierre
Obligatorio: todos los casos funcionales PASS (mapa no puede declararse PASS con matriz de contingencia), 10 PDF y 10 Excel, 8+7 páginas, 10 RDL publicados, no regresiones, evidencia y PR integrado. Rendimiento fuera de objetivo exige incidencia y aceptación explícita de Castilla antes de demo; no afirmar certificación de rendimiento. Resultado final consignar PASS/FAIL/BLOCKED por dominio, no promedio arbitrario.
