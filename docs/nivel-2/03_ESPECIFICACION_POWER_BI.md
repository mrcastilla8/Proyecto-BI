# 03 — Especificación de Power BI Live

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Configuración de base
Duplicar el PBIX existente fuera de master; comprobar conexión Live a `BI_OLIST_Tabular`. No pulsar «Realizar cambios en este modelo». Conservar ocho medidas, no crear medidas locales ni cálculos visuales. Importar tema, construir menú, cabecera y panel de filtros. Excluir `DimFecha` desconocida (fecha/año vacío) consistentemente P01–P07; conciliación total debe usar el mismo filtro. La fecha es compra. Default: histórico completo; no fecha actual. Si hay meses parciales, advertirlos, no eliminarlos en silencio.

## Diccionario de medidas (alias en esta guía, no nuevos DAX)
| Alias | Campo exacto |
|---|---|
| V | ventas_productos_entregados |
| E | pedidos_entregados_con_items |
| P | pedidos_totales |
| T | ticket_promedio_productos_entregados |
| F | flete_pedidos_entregados |
| C | porcentaje_entregas_a_tiempo |
| D | dias_promedio_entrega |
| S | calificacion_promedio |
`Fecha` = `DimFecha[fecha]`/jerarquía Calendario; `EC`/`CC` = `DimGeografiaCliente[customer_state/customer_city]`; `EV` = `DimGeografiaVendedor[seller_state]`; `Cat` = `DimProducto[product_category_name_english]`; `Prod` = `DimProducto[product_id]`; `Vend` = `DimVendedor[seller_id]`. Las columnas se usan como ejes/filtros/detalle, no como nuevas medidas implícitas.

## Layout por página
Todos los KPI ocupan la fila y112–244 (cuatro columnas, dos filas si ocho KPI: y112–176 y192–256). Área analítica y272–1000 en dos filas o una tabla inferior; ajustar dentro de la retícula de 02. Para cada visual, registrar ID, tipo, campos, interacciones, formato, tooltip y prueba en `powerbi/validacion/inventario-visuales.csv`. Los Top N son filtros visuales fijos, no rankings DAX; aplicar por V, excluir blank y ordenar descendente. Empates pueden ampliar el conjunto; no prometer cardinalidad estricta en PBI. No sumar conteos distintos por categoría o vendedor.

### P01 — Resumen ejecutivo (Castilla)
| ID | Visual / ubicación | Campos | Interacción |
|---|---|---|---|
| P01-01..08 | 8 tarjetas, dos filas | V,E,P,T,F,C,D,S | Fecha/EC; sin resaltado de categorías |
| P01-09 | Línea, x280 y272 w1068 h340 | Fecha (mes), V | Tooltip T01 |
| P01-10 | Barras, x1364 y272 w532 h340 | Cat, V (Top 5) | No filtra KPI generales; tooltip T02 |
| P01-11 | Columnas agrupadas x280 y628 w800 h372 | Fecha (mes), P y E | Solo fecha/EC; aclarar distintas poblaciones |
| P01-12 | Accesos x1096 y628 w800 h372 | Botones R01,R02,P08 | URL fija |
Aceptación: ocho valores coinciden con SSAS, las tarjetas responden al período y EC; seleccionar categoría no altera cabecera, navegación funciona.

### P02 — Inteligencia comercial (Ángel)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P02-01..04 | Tarjetas | V,E,T,F |
| P02-05 | Línea x280 y260 w1068 h330 | Calendario año/trimestre/mes, V |
| P02-06 | Línea x1364 y260 w532 h330 | Fecha mes, T |
| P02-07 | Matriz calor x280 y606 w800 h394 | anio, mes/nombre_mes orden cronológico, V |
| P02-08 | Columnas x1096 y606 w392 h394 | dia_semana (código, validar significado), E |
| P02-09 | Columnas x1504 y606 w392 h394 | Fecha trimestre, F |
T01 en series temporales; R02 en cabecera. No usar crecimiento ni acumulados calculados. Probar drill-down, orden calendario, período sin datos y segmentadores.

### P03 — Productos y categorías (Ángel)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P03-01..04 | Tarjetas | V,E,T,F |
| P03-05 | Barras x280 y260 w800 h330 | Cat,V Top 10 |
| P03-06 | Treemap x1096 y260 w800 h330 | Cat,V |
| P03-07 | Matriz x280 y606 w1068 h394 | jerarquía Categoría y producto, V,E,T,F |
| P03-08 | Barras agrupadas x1364 y606 w532 h394 | Cat,V,F Top 5 |
Filtros locales Cat y Prod, T02 en gráficos de categoría/producto, D01 desde Prod en matriz. R04 fijo. No mostrar calificación, P, C o D. Probar total distinto, selección de categoría y retorno desde D01.

### P04 — Desempeño de vendedores (Cueva)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P04-01..04 | Tarjetas | V,E,T,F |
| P04-05 | Barras x280 y260 w800 h330 | Vend,V Top 10; ID completo en tooltip |
| P04-06 | Dispersión x1096 y260 w800 h330 | Vend como detalle, V x, T y, E tamaño; limitar Top 100 por V si necesario y rotular |
| P04-07 | Matriz x280 y606 w1068 h394 | Vend,V,E,T,F; EV no necesariamente atributo unívoco del vendedor |
| P04-08 | Barras x1364 y606 w532 h394 | EV,F |
EV/Vend locales; D02 desde matriz. R03 fijo. Evitar truncamiento ambiguo de IDs: mostrar completos en matriz y tooltip, si no caben en ranking reducir Top N o ancho. Probar filtros y conteo no aditivo.

### P05 — Logística (Cueva)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P05-01..04 | Tarjetas | C,D,P,F |
| P05-05 | Líneas separadas o gráfico combinado x280 y260 w1068 h330 | Fecha mes, C y D con ejes y unidades explícitas |
| P05-06 | Barras x1364 y260 w532 h330 | FactPedidos.order_status, P; escala lineal, etiquetas |
| P05-07 | Dispersión x280 y606 w800 h394 | EC, C x, D y, P tamaño |
| P05-08 | Matriz x1096 y606 w800 h394 | EC, C,D,P; formato condicional relativo |
T03 sobre contexto de cabecera; R05 fijo. Estado del pedido solo afecta visuales de FactPedidos, no F. F se etiqueta «entregados». No presentar comparación como causalidad. Probar estado cancelado: C y D vacíos, P conserva contexto. No meta SLA inventada.

### P06 — Experiencia del cliente (Basualdo)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P06-01..04 | Tarjetas | S,C,D,P |
| P06-05 | Línea x280 y260 w800 h330 | Fecha mes,S; eje 1–5 |
| P06-06 | Barras x1096 y260 w800 h330 | EC,S (orden ascendente, escala declarada) |
| P06-07 | Dispersión x280 y606 w800 h394 | EC,C x,S y,P tamaño |
| P06-08 | Matriz x1096 y606 w800 h394 | EC→CC,S,C,D,P |
T04; R06 fijo. Anotar que P es volumen total, no número de reseñas; pequeñas poblaciones y meses parciales requieren cautela. No afirmar causalidad. Probar estado/city y blank.

### P07 — Inteligencia geográfica (Basualdo)
| ID | Visual / ubicación | Campos |
|---|---|---|
| P07-01..04 | Tarjetas | V,P,C,S |
| P07-05 | Shape Map x280 y260 w800 h420 | EC,V; marcador alterna V/C con dos visuales existentes (sin DAX) |
| P07-06 | Barras x1096 y260 w800 h420 | EC,V |
| P07-07 | Matriz x280 y696 w1616 h304 | EC→CC,V,P,C,D,S |
Filtro local CC; D03 desde EC en matriz, T04 en barras/mapa si soportado. R09 fijo. TopoJSON local de 27 UF con claves AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO; verificar unicidad, límites, licencia y asociación exacta. Fuente preferida IBGE, registrar versión y licencia antes de redistribuir. No geocodificar códigos fuera de Brasil. Si Shape Map no soporta Live/versión, sustituir temporalmente por matriz y registrar BLOCKED_MAP; no declarar aceptación cartográfica. Ver Microsoft: https://learn.microsoft.com/power-bi/visuals/desktop-shape-map .

### P08 — Centro de informes (Castilla)
Sin segmentadores ni KPI; 10 tarjetas/botones agrupados por Gerencia, Comercial, Operaciones, Auditoría; código, propósito y URL real. Añadir instrucciones: filtros no se transfieren; seleccionar en portal; R08 requiere OrderId. Botón portal. Ver 07 para rutas.

## Auxiliares (ocultas del navegador)
| ID | Responsable | Campo de contexto / contenido |
|---|---|---|
| T01 | Ángel | Fecha; V,E,T,F |
| T02 | Ángel | Cat/Prod; V,E,T,F |
| T03 | Cueva | Fecha/EC; C,D,P |
| T04 | Basualdo | EC/CC; P,C,D,S |
| D01 | Ángel | Prod en drill-through; V,E,T,F, serie fecha, Cat/ID; volver |
| D02 | Cueva | Vend; V,E,T,F, serie fecha, EV si compatible; volver |
| D03 | Basualdo | EC; V,P,C,D,S, matriz CC y tendencia; volver |
Configurar Keep all filters en drill-through y probar compatibilidad de filtros; no arrastrar filtros locales de grano incompatible. Asignar tooltip explícitamente si no se activa automáticamente. Navegador excluye ocultas; probar retorno y contexto. Ver https://learn.microsoft.com/power-bi/create-reports/desktop-tooltips y https://learn.microsoft.com/power-bi/create-reports/desktop-drillthrough .

## Matriz de interacciones y entrega
Fecha/EC sincronizados P01–P07, panel filtros en cada página; Cat/Prod P03, EV/Vend P04, estado cabecera P05, CC P07. En P01 categoría no afecta ningún visual de cabecera; en P05 estado cabecera no afecta F. Deshabilitar explícitamente interacciones incompatibles. En P07 mapa y barras filtran matriz solo por EC. Marcador «Mapa ventas / puntualidad» con Data desactivado; reset restaura valores predeterminados incluyendo sincronizados y se prueba. Usar Control+clic en Desktop cuando aplique a botones. Registrar nombres de visuales en panel selección. Entregar PBIX individual por responsable, captura 1920×1080 por página, inventario y evidencia de filtros; Ángel integra navegación, tooltips y drill-through en único maestro. Sin nube ni dependencias de visuales de terceros.
