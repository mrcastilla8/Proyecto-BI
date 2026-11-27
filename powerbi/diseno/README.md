# Plantilla Power BI OLIST 360° (A01)

Responsable Ángel (`@luisdem01`). La aprobación visual de G1 corresponde a Castilla (`C02`). Implementa [02_SISTEMA_DISENO_VISUAL.md](../../docs/nivel-2/02_SISTEMA_DISENO_VISUAL.md) y la configuración de base de [03_ESPECIFICACION_POWER_BI.md](../../docs/nivel-2/03_ESPECIFICACION_POWER_BI.md).

**Estado:** implementada y comprobada en Power BI Desktop el 26-11-2026 con conexión Live y datos reales. Está pendiente de la aprobación final `C02`.
- El tema **OLIST 360** está importado.
- La plantilla se abrió en Desktop.
- Las capturas están en [`powerbi/evidencias/nivel-2/A01.md`](../evidencias/nivel-2/A01.md).

## Contenido

| Archivo | Uso |
|---|---|
| [../themes/olist360.json](../themes/olist360.json) | Tema de Power BI. Se importa con **Vista → Temas → Examinar temas**. |
| `OLIST360_Plantilla.pbip` | Proyecto PBIP con conexión Live a `BI_OLIST_Tabular` en `localhost`. Incluye el tema ya registrado. |
| Página `P00 · Plantilla` | Marco común con 4 KPI y 3 visuales de ejemplo. Es la base que se duplica para cada página nueva. |
| Página `Guía de retícula` | Zonas rotuladas con sus coordenadas. Sirve de referencia y no forma parte del informe final. |

La plantilla no crea medidas, columnas, tablas ni cálculos visuales. Solo usa medidas del contrato v1.

## Tema

| Token | HEX | Uso en el tema |
|---|---|---|
| Navy | `#101C32` | Menú lateral, encabezados de tabla y matriz, tercer color de datos |
| Blue | `#2563EB` | Primer color de datos (ventas), acento de tabla, botón activo y restablecer |
| Teal | `#0D9488` | Segundo color de datos (logística y experiencia) |
| Amber | `#D97706` | Color neutral y cuarto color de datos |
| Emerald | `#059669` | Color favorable. Se usa solo con un criterio declarado |
| Red | `#DC2626` | Color desfavorable o de incidencia |
| Canvas | `#EAF0F7` | Fondo de página y totales |
| White | `#FFFFFF` | Fondo de los visuales |
| Ink | `#14233B` | Texto y títulos |
| Muted | `#475569` | Subtítulos, ejes y leyendas |
| Border | `#CBD5E1` | Bordes de visual (radio 8) |

Valores adicionales que **no son tokens** y requieren el visto bueno de C02:
- `#F8FAFC` para las filas alternas, tomado de la plantilla RDL de Poma.
- `#E2E8F0` para la cuadrícula.
- Tintes claros `#93C5FD`, `#5EEAD4` y `#94A3B8` para la sexta a octava serie.

Tipografía Segoe UI: valores KPI de 32 pt, títulos de visual de 14 pt y etiquetas de 11–12 pt. Sin sombras, degradados ni 3D.

## Retícula (lienzo 1920×1080)

| Zona | Coordenadas |
|---|---|
| Menú lateral | x0 y0 w256 h1080 |
| Cabecera | x256 y0 w1664 h88: código, título de página (28 pt) y pregunta de negocio |
| Pie | x280 y1020 w1616 h40: fuente, SSAS Live, BRL nominales, fecha de compra y código de página |
| Contenido | x280–1896, y112–1000, separación de 16 px |
| KPI | y112–244 en 4 columnas de 392 px (x280, 688, 1096, 1504). Con 8 KPI se usan dos filas: y112–176 y y192–256 |
| Dos columnas | w800 en x280 y x1096 |
| 2/3 + 1/3 | w1068 en x280 y w532 en x1364 |

## Componentes

- **Navegación:** ocho botones nativos P01–P08 de 224×44 px con nombres cortos que se leen completos: *P01 Resumen ejecutivo*, *P02 Inteligencia comercial*, *P03 Productos*, *P04 Vendedores*, *P05 Logística*, *P06 Experiencia*, *P07 Geografía* y *P08 Centro de informes*. Usan la acción *Navegación de página*, el mismo patrón que las entregas de Cueva. El botón de la página actual usa Blue `#2563EB` y los demás `#33466A`. Este tono intermedio entre Navy y Muted no es un token y requiere aprobación C02. En la plantilla los botones no tienen destino, porque las páginas P01–P08 aún no existen. El destino se asigna en el PBIX maestro (A07).
- **Panel de filtros:** dos segmentadores en el menú. *Fecha de compra* usa `DimFecha[fecha]` en modo entre y *Estado del cliente* usa `customer_state` como lista desplegable. Debajo va el botón **Restablecer filtros**, con la acción nativa *Borrar todas las segmentaciones*, sin marcadores.
- **Grupos de sincronización:** son un contrato para P01–P07. Cada autor debe conservar estos nombres para que la integración del maestro no pierda la sincronización:

  | Grupo | Campo |
  |---|---|
  | `olist360_fecha_compra` | `DimFecha[fecha]` |
  | `olist360_estado_cliente` | `DimGeografiaCliente[customer_state]` |

- **Filtro de página:** `DimFecha[anio]` excluye el año vacío del miembro técnico `-1`. Debe mantenerse en cada página.
- **KPI:** tarjeta clásica con título comercial corto, subtítulo `Medida: <nombre técnico>` y valor a 32 pt, sin la etiqueta interna repetida. Sin flechas de crecimiento ni semáforos.

## Cómo usarla (G2)

1. Copia `OLIST360_Plantilla.pbip` y sus dos carpetas `.Report` y `.SemanticModel` a `powerbi/entregas/<apellido>/` con un nombre propio.
2. Abre la copia en Power BI Desktop y duplica `P00 · Plantilla` para cada página asignada. Elimina la `Guía de retícula`.
3. Cambia el código, el título y la pregunta de la cabecera, y el código del pie. Reemplaza los visuales de ejemplo respetando la retícula.
4. No pulses *Realizar cambios en este modelo* ni agregues medidas.

## Pendiente

- **Restablecer filtros con un estado seleccionado.** Comprobado con un rango de fechas: las fechas vuelven al rango completo y los KPI al total. Falta la captura con un estado del cliente seleccionado antes de pulsar el botón.
- **Legibilidad en una pantalla real de 1366×768 o en el proyector.** La captura disponible es de una ventana de Desktop reducida.
