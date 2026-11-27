# Entrega individual de Power BI de Castilla (C03 · C04)

`OLIST360_Castilla.pbip` contiene **P01 · Resumen ejecutivo** (`c1a00000000000000001`), **P08 · Centro de informes** (`c1a00000000000000008`) y copias locales con IDs únicos de **T01** (`c1a000000000000000a1`) y **T02** (`c1a000000000000000a2`), construidos sobre la [plantilla OLIST 360](../../diseno/README.md) y el tema `olist360.json`.

## Alcance implementado
- **Conexión Live:** `BI_OLIST_Tabular` sin medidas DAX locales, columnas calculadas, tablas locales ni modelo compuesto.
- **P01 · Resumen ejecutivo:** 8 tarjetas KPI (`ventas_productos_entregados`, `pedidos_entregados_con_items`, `pedidos_totales`, `ticket_promedio_productos_entregados`, `flete_pedidos_entregados`, `porcentaje_entregas_a_tiempo`, `dias_promedio_entrega`, `calificacion_promedio`), línea mensual de ventas (tooltip T01), Top 5 categorías por ventas (tooltip T02, interacción `NoFilter` hacia los 8 KPI y comparación de pedidos), columnas agrupadas de pedidos totales vs. entregados con ítems, y accesos a R01, R02 y P08.
- **P08 · Centro de informes:** 10 tarjetas/botones agrupados por Gerencia (`R01`, `R02`), Comercial (`R03`, `R04`, `R07`), Operaciones (`R05`, `R06`, `R08`, `R09`) y Auditoría (`R10`), más botón del portal SSRS y aviso explícito de que los filtros de Power BI no se transfieren a Reporting Services (y que `R08` exige `OrderId` en el portal).

## Uso e integración
1. Si la instancia local de SSAS difiere de `localhost` (por ejemplo `.\SSASBI`), actualizarla localmente en **Transformar datos → Configuración de origen de datos** sin versionar host personal.
2. En el PBIX maestro integrado (`powerbi/BI_OLIST.pbix` bajo custodia de Ángel), sustituir `{{SSRS_WEB_SERVICE_URL}}` y `{{SSRS_WEB_PORTAL_URL}}` por las URLs reales del equipo demo y reasignar T01/T02 a las páginas únicas del maestro (`c6eb53669c7346ba553f` y `8dbf4d91c8076fdf07a9`).

Inventario de visuales: [`powerbi/validacion/inventario-visuales-castilla.csv`](../../validacion/inventario-visuales-castilla.csv).
