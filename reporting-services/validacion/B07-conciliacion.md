# B07 · Matriz de conciliación de R06 y R09

Base de integración `4c90279`. Los informes y el PBIX individual corresponden a la [entrega #17](https://github.com/mrcastilla8/Proyecto-BI/pull/17). Se reutilizaron las evidencias de [B01](../../powerbi/evidencias/nivel-2/BASE-03.md), [R06](R06.md), [R09](R09.md) y [Report Builder](report-builder.md). Se repitieron los totales y el caso vacío en Windows contra el DW local con los datasets versionados. También se leyeron los valores numéricos de ambos XLSX guardados.

## R06 · Satisfacción

| Fecha de compra, estado y notas | SQL de R06 | Comparación y estado |
|---|---|---|
| 04/09/2016–17/10/2018 · todos · 1–5 | **98.673** notas válidas, promedio **4,0867934146** | Coincide con el promedio DAX total de B01 dentro de `1e-7`. P06 individual muestra **4,09**. |
| 2017 · SP · 1–5 | **17.614** notas válidas, promedio **4,1544699273** | Coinciden el conteo y el promedio en SSAS. El promedio también coincide con el SQL de R09 bajo el mismo filtro. P06 individual muestra **4,15**. |
| 2017 · SP · 3,25–4,5 | **3.427** notas, promedio **4,0003890575** | Coinciden el conteo y el promedio del subconjunto en SSAS y en el XLSX. Los rangos suman **8 + 3.419** notas y los 12 meses suman **3.427**. |
| 2016 · AC · 1–5 | **0 filas** | SSAS devuelve `BLANK` en conteo y promedio. P06 individual mostró tarjetas y matriz vacías. Para el SQL se usó la parte válida de 2016, del 04/09 al 31/12, para que el resultado vacío no procediera de la guarda de fechas. |

La unidad de R06 es una **nota válida por pedido**. Las **768** notas nulas del histórico quedan fuera del promedio. R09 contabiliza **99.441** pedidos históricos y **17.760** en 2017 y SP porque su total incluye pedidos con y sin nota.

## R09 · Desempeño regional

Los importes están en BRL y la puntualidad se expresa como proporción para el cotejo.

| Fecha de compra y geografía | Ventas | Entregados con ítems | Pedidos | Ticket | Flete | Puntualidad | Días | Nota |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 04/09/2016–17/10/2018 · todos | 13.221.498,11 | 96.478 | 99.441 | 137,0415857501 | 2.198.275,64 | 0,9322690992 | 12,5582170981 | 4,0867934146 |
| 2017 · SP · todas las ciudades | 2.136.258,96 | 17.071 | 17.760 | 125,1396496983 | 291.743,66 | 0,9619214997 | 9,3434623175 | 4,1544699273 |
| 2017 · SP · São Paulo | 752.425,64 | 6.123 | 6.381 | 122,8851282051 | 100.270,40 | 0,9593336600 | 8,6403928342 | 4,1208504584 |

| Cotejo | Estado y evidencia |
|---|---|
| Histórico SQL ↔ DAX | **Verificado.** Las ocho cifras concilian con la fila `total` de B01. Los conteos y los importes sumados son exactos. Los cocientes y promedios cumplen la tolerancia absoluta de `1e-7`. |
| SP y São Paulo en 2017 | **Verificado en SSAS y en la entrega individual.** Las ocho métricas de ambos filtros conciliaron directamente contra SSAS con igualdad exacta en conteos e importes sumados y tolerancia de `1e-7` en cocientes y promedios. P06/P07 concilian las cifras visibles con el DW. D03 recibe el filtro SP y 2017. En São Paulo, las ocho cifras del XLSX local coinciden en las filas de total, estado y ciudad. Cada nivel se compara por separado. [P06](../../powerbi/evidencias/nivel-2/P06.md) · [P07](../../powerbi/evidencias/nivel-2/P07.md) · [T04 y D03](../../powerbi/evidencias/nivel-2/T04-D03.md) |
| Ausencia de actividad o de elegibles | **Verificado localmente.** Para AC en el período válido de 2016 R09 devuelve cero filas y las ocho medidas en SSAS devuelven `BLANK`, coherente con P06 individual en blanco. En Cacimbinhas (AL), R09 conserva un pedido y nota 1, con ventas y entregados en `NULL`. B01 ya verificó 18 pares SQL `NULL` / DAX `BLANK` en sus escenarios originales. |

## Reproducción del cotejo SQL/DAX

En Windows PowerShell 5.1 con ADOMD.NET, se consultó el catálogo local `BI_OLIST_Tabular` en modo de solo lectura. Se usó `EVALUATE CALCULATETABLE(ROW(...), ...)` con las ocho medidas originales de [metricas.dax](../../ssas/validacion/metricas.dax) para R09. Aplicar `DimFecha[anio]` y `DimGeografiaCliente[customer_state]` y agregar `DimGeografiaCliente[customer_city] = "sao paulo"` para la fila de ciudad. Para R06, consultar `COUNT('FactPedidos'[review_score])` y `[calificacion_promedio]` con los límites inclusivos sobre `FactPedidos[review_score]`. Se conciliaron **30 valores** en seis escenarios, incluidos diez `BLANK` en los dos casos de AC.

## Pendientes de integración

| Responsable | Comprobación para cerrar B07 |
|---|---|
| **Ángel habilita la prueba y Marcos concilia** | En el PBIX maestro Live, repetir histórico, 2017 + SP, São Paulo y 2016 + AC. Comparar los valores en el mismo contexto de compra y geografía. Verificar filtros sincronizados de P01 a P07 (`PBI-04`), contexto de T04, entrada y regreso de D03, y enlaces oficiales. Usar valores sin redondear para acreditar `1e-7`. |
| **Gabriel Poma publica y Marcos concilia** | En SSRS, resolver el origen compartido y reproducir los filtros de R06 y R09, incluidos rango decimal, vacío y niveles de total/estado/ciudad (`SSRS-08` y `SSRS-11`). Comparar los PDF y XLSX del servidor con las cifras de la matriz y probar los enlaces entre informes. |

La conciliación local queda documentada. El resultado en el PBIX maestro y en el portal queda pendiente de ejecución. Shape Map sigue como `BLOCKED_MAP` en `PBI-08`, con la matriz por estado como alternativa funcional.
