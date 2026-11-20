# Power BI

Responsable Ángel (`@luisdem01`), rama `angel/powerbi-reportes`. Basualdo revisa las medidas.

[BI_OLIST.pbix](BI_OLIST.pbix) es un informe de Power BI Desktop con conexión **Live** al catálogo SSAS Tabular `BI_OLIST_Tabular`. No importa tablas ni define medidas propias. Cada visual usa medidas del [contrato de métricas](../contracts/metricas.v1.json) y su subtítulo indica el nombre técnico de la medida. El archivo no contiene datos ni modelo local, solo la conexión y el diseño.

## Abrir y reconectar

1. Despliega y procesa `BI_OLIST_Tabular` en una instancia SSAS Tabular local siguiendo el [procedimiento SSAS](../ssas/README.md). El cotejo `Comparar-Metricas.ps1` debe pasar.
2. Abre `BI_OLIST.pbix` con Power BI Desktop. El archivo apunta a `localhost`. Si tu instancia tiene otro nombre, usa **Transformar datos → Configuración de origen de datos → Cambiar origen** y deja `BI_OLIST_Tabular` como base de datos.
3. La barra inferior debe indicar *Conexión dinámica: conectada*. Si en *Obtener datos* el campo Servidor no se valida, escribe el nombre a mano y pulsa Tab.

La conexión usa autenticación de Windows dentro de la red local. Nunca expongas SQL Server ni SSAS a internet para publicar el informe.

## Páginas

Todas las páginas excluyen el miembro técnico de fecha `-1` (año vacío) con un filtro de página. Los segmentadores de año y de estado del cliente están sincronizados entre páginas.

| Página | Visuales | Medidas |
|---|---|---|
| 1. Resumen ejecutivo | 8 tarjetas; ventas por mes de compra; top 10 categorías; pedidos totales frente a entregados por mes; ventas por estado del cliente | Las ocho del contrato |
| 2. Logística y cumplimiento | 4 tarjetas; % a tiempo y días por mes de compra; pedidos por `order_status`; tabla de cumplimiento por estado del cliente con escala de color; flete por estado del vendedor | `porcentaje_entregas_a_tiempo`, `dias_promedio_entrega`, `flete_pedidos_entregados`, `pedidos_totales` |
| 3. Productos y vendedores | 4 tarjetas; top 10 categorías con ventas y flete; top 10 vendedores; detalle por vendedor | Solo medidas de `FactDetallePedido` |
| 4. Satisfacción y geografía | 4 tarjetas; calificación por mes de compra; calificación por estado del cliente; dispersión de % a tiempo frente a calificación por estado; matriz Estado › Ciudad | `calificacion_promedio`, `pedidos_totales`, `porcentaje_entregas_a_tiempo`, `dias_promedio_entrega` |

## Limitaciones

- **Las fechas de los ejes son de compra.** Las relaciones con las fechas estimada y real de entrega están inactivas y el modelo no ofrece medidas que las activen. Los visuales no se agrupan por mes de entrega.
- **Producto, vendedor y geografía del vendedor solo filtran `FactDetallePedido`.** Por eso puntualidad, días de entrega y calificación no aparecen cruzadas con esas dimensiones. Para mostrarlas hace falta una medida nueva en SSAS, no una medida local del informe.
- **Los meses con pocos pedidos producen promedios extremos.** 2016 tiene 329 pedidos y septiembre y octubre de 2018 muy pocos. Por ejemplo, septiembre de 2016 muestra 55 días de entrega y la calificación mensual llega a 1 y a 5. Son valores reales del modelo, no errores.
- **Los vendedores se identifican por `seller_id`**, porque el dataset Olist está anonimizado. Las categorías usan `product_category_name_english`.
- **Los importes son BRL nominales.** No representan utilidad ni margen.

## Evidencia

Evidencia real del 20-11-2026 en [evidencias/INDICE.md](evidencias/INDICE.md). Incluye la reproducción local de la cadena SQL Server → SSIS → SSAS y las capturas de la conexión Live y de las cuatro páginas. Sin filtros, las tarjetas coinciden con el escenario `total` del cotejo SQL/DAX: R$ 13.221.498,11; 96.478; 99.441; R$ 137,04; R$ 2.198.275,64; 93,23 %; 12,56; 4,09.
