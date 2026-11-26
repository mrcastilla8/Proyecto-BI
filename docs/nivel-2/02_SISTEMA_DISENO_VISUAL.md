# 02 — Sistema de diseño visual

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Identidad
OLIST 360° — Business Intelligence Suite (identidad académica, no afiliación oficial). Apariencia de aplicación empresarial: navegación azul marino, superficie clara, gráficos legibles. El color indica significado y se acompaña de texto/símbolo, no es la única señal.

| Token | HEX | Uso |
|---|---|---|
| Navy | #101C32 | Menú y cabecera RDL |
| Blue | #2563EB | Ventas, selección y acción primaria |
| Teal | #0D9488 | Logística/experiencia |
| Emerald | #059669 | Resultado favorable, solo con criterio declarado |
| Amber | #D97706 | Advertencia |
| Red | #DC2626 | Retraso/incidencia |
| Canvas | #EAF0F7 | Fondo |
| White | #FFFFFF | Tarjetas |
| Ink | #14233B | Texto |
| Muted | #475569 | Texto secundario |
| Border | #CBD5E1 | Divisores |

Segoe UI, títulos principales 28–32 pt, KPI 32–44 pt, etiquetas 12–14 pt. Asegurar contraste mínimo objetivo 4,5:1 para texto normal; usar colores oscuros para texto sobre blanco. No gradientes decorativos, 3D, marcas de agua ni tipografía diminuta.

## Retícula PBI (coordenadas de lienzo, px)
Lienzo 1920×1080; menú x0 y0 w256 h1080; cabecera x256 y0 w1664 h88; pie x280 y1020 w1616 h40; contenido x280..1896, y112..1000. Separación 16. Cuatro columnas de 392 px (x280,688,1096,1504). Para dos columnas usar x280 y1096, w800 cada una; para 2/3 y 1/3 usar w1068 y532. Ningún visual se sale ni se superpone. Escalar captura a 1366×768 y proyector; aumentar texto si resulta ilegible. Las posiciones de 03 son referencias de implementación, no capturas reales.

## Componentes reutilizables
- Navegador P01–P08, estado activo, regreso en detalle, ayuda de filtros y restablecer. Botones nativos con texto y área clicable suficiente.
- KPI: título comercial corto, valor, unidad y contexto; tooltip explica medida, grano y elegibilidad. No flecha de crecimiento ni semáforo sin referencia válida; puntualidad puede usar color neutro.
- Gráficos: título que declara pregunta, unidad y eje; fechas orden cronológico, categorías ordenadas por valor, etiquetas limitadas, sin duplicar leyendas. Identificadores largos solo en detalle o tooltip. Categoría inglesa se conserva, no inventar traducciones ni columnas.
- Panel filtros: fecha de compra, región cliente (sincronizados P01–P07), filtros locales donde correspondan; abrir/cerrar con marcador de visualización sin Data; reset explícito con Data. El reset por página puede afectar sincronizados: etiquetar y verificar.
- Pie: fuente Olist, SSAS Live, BRL nominales, número de página; nota de fecha de compra y período parcial cuando corresponda. BLANK se muestra como vacío/guion con leyenda, nunca cero fabricado.
- Tooltips 480×300 aprox., 2–4 KPI y contexto; drill-through 1920×1080 con retorno nativo y filtros heredados compatibles.

## RDL
A4 vertical R01/R08; A4 horizontal restantes; márgenes 12 mm cada lado. Ancho máximo 186 mm vertical / 273 mm horizontal; reservar margen de seguridad 2 mm (cuerpo ≤184/271 mm). Cabecera navy con título, ID, período y filtros; pie con número de página y fuente. Tipografía 9–11 pt tablas, 14–20 títulos; filas alternas, encabezados repetidos, valores alineados a derecha, ID completo en columnas legibles o líneas envueltas. Evitar merges excesivos que rompan Excel. Configurar `Language` explícitamente (es-PE o es-ES validado), símbolo `R$` explícito y dos decimales, fechas dd/MM/yyyy. Exportar y revisar PDF y Excel real, no solo preview.

## Archivos a entregar
`powerbi/themes/olist360.json` (tema importado y validado), `powerbi/diseno/` (retícula, iconos locales originales/licenciados y notas), `reporting-services/diseno/` (plantilla RDL, assets y licencia). No declarar tema implementado hasta importar en Desktop; no incluir archivos de fuentes ni logos comerciales no autorizados. Capturas antes/después a 1920×1080.
