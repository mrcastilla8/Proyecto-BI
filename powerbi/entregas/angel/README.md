# Entrega individual de Power BI de Ángel

`OLIST360_Angel.pbip` contiene P02, P03, T01, T02 y D01 en formato PBIR, construidos sobre la [plantilla OLIST 360](../../diseno/README.md). La conexión es Live a `BI_OLIST_Tabular` en `localhost`, con el mismo `modelReference.json` que la plantilla aprobada.

1. Abre `OLIST360_Angel.pbip` en Power BI Desktop y comprueba que la barra inferior indica *Conexión dinámica: conectada*. Si tu instancia SSAS tiene otro nombre, cámbialo en **Transformar datos → Configuración de origen de datos**.
2. En una copia de trabajo, sustituye `{{SSRS_WEB_SERVICE_URL}}` en los botones R02 (P02) y R04 (P03) por la URL del servicio registrada por Poma.
3. Pruebas:
   - En P02, la línea de ventas baja de año a trimestre y a mes.
   - Las series de P02 muestran T01.
   - Los gráficos de categoría de P03 muestran T02.
   - Clic derecho en un producto de la matriz de P03 → **Obtener detalles → D01**, y **← Volver** regresa a P03.

Evidencia: [A02-A04.md](../../evidencias/nivel-2/A02-A04.md). Inventario de visuales: [inventario-visuales-angel.csv](../../validacion/inventario-visuales-angel.csv).
