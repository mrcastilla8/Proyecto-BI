# Entrega individual de Power BI de Cueva

`OLIST360_Cueva.pbip` contiene P04, P05, T03 y D02 en formato PBIR. La referencia `byPath` conserva la conexión Live a `BI_OLIST_Tabular` mediante el `modelReference.json` generado por Desktop para el entorno local.

## PBIX individual validado

`OLIST360_Cueva.pbix` se guardó desde el proyecto probado en Power BI Desktop. Contiene P04, P05, T03 y D02 y mantiene conexión Live a `BI_OLIST_Tabular`, sin datos importados. El origen apunta a la instancia local de SSAS usada en la prueba. En otro equipo, configurar la conexión a su instancia autorizada.

Los enlaces P04 → R03 y P05 → R05 quedan pendientes de las URLs oficiales y de la validación en el portal SSRS.

## Reproducir desde el PBIP

1. En Power BI Desktop, abre una copia individual de `BI_OLIST.pbix`, conecta a la instancia local autorizada de SSAS y guárdala como proyecto `OLIST360_Cueva.pbip` en otra carpeta. Copia desde allí la carpeta generada `OLIST360_Cueva.SemanticModel` junto al `.pbip` de esta entrega. Esa carpeta queda local porque contiene la conexión del laboratorio.
2. En la copia de trabajo, sustituye `{{SSRS_WEB_SERVICE_URL}}` en las dos acciones `WebUrl` por la URL del servicio registrada por el equipo. Los botones abren R03 y R05 con selección de filtros en SSRS.
3. Abre `OLIST360_Cueva.pbip`, verifica que Desktop indica conexión Live y guarda como PBIX individual. Prueba que el filtro de estado de cabecera en P05 no modifica el flete, que los gráficos de logística muestran T03 y que una selección de vendedor en la matriz de P04 abre D02 y permite volver.
