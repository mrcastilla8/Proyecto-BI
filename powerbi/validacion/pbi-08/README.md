# P07 · Mapa de las 27 unidades federativas de Brasil

[brasil-uf.topojson](brasil-uf.topojson) contiene una geometría por UF. El identificador y las propiedades `name` y `SIGLA_UF` usan la sigla de dos letras que espera `DimGeografiaCliente[customer_state]`. `NM_UF` y `CD_UF` conservan el nombre y código del IBGE.

## Integración y prueba

1. En una copia de P07 conectada en vivo a `BI_OLIST_Tabular`, agregar el visual **Mapa de formas**.
2. En **Formato visual → Configuración del mapa → Tipo de mapa → Mapa personalizado**, cargar el archivo. Abrir **Ver clave de tipo de mapa** y verificar las 27 siglas.
3. Usar `DimGeografiaCliente[customer_state]` en **Ubicación** y la medida existente `ventas_productos_entregados` en **Saturación del color**. Para la vista de puntualidad, reutilizar `porcentaje_entregas_a_tiempo` en el segundo visual previsto por el diseño.
4. Probar el histórico y el filtro `2017 + SP`. Comparar las cifras del mapa con la matriz de P07 y comprobar que el estado resaltado sea São Paulo. Verificar también RJ, DF y AM y registrar captura, versión de Desktop, SHA del archivo, resultado y fecha en `PBI-08`.

La verificación local del archivo confirmó 27 claves únicas iguales a las de la especificación, 36 anillos cerrados y 4.985 posiciones recuperadas sin pérdida respecto de la fuente. Las coordenadas de referencia de São Paulo, Río de Janeiro, Brasilia y Manaus quedaron dentro de SP, RJ, DF y AM, respectivamente. La importación y la interacción en Power BI Desktop con conexión Live siguen pendientes.

[Shape Map en Power BI](https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-shape-map#load-a-custom-map) · [Especificación Power BI](../../../docs/nivel-2/03_ESPECIFICACION_POWER_BI.md)

## Fuente y licencia

Límites territoriales del Instituto Brasileiro de Geografia e Estatística (IBGE), API de Malhas v3, a través de *Municípios e estados do Brasil*, de Caique Dourado, versión de datos 1.2.0. Se fijó el commit `004b7cd546d158081dc3ca0956f0c9a89dcdcd3c` y el blob de origen `1bd1207d25eed2833a87890e620623c4d11c63c9`. La publicación consultada identifica la versión del conjunto de datos, sin indicar el año de edición de los polígonos.

Adaptación para OLIST 360°. Se convirtieron los polígonos GeoJSON a TopoJSON, se normalizó el sentido de los anillos para proyección esférica, se compartieron los arcos coincidentes y se asignaron las siglas como claves. Se conservaron todos los vértices en grados decimales a la precisión de la fuente. El mapa derivado se distribuye bajo CC BY 4.0 con atribución a IBGE y a Caique Dourado. Los campos base de identificación conservan el aviso MIT de Kelvin S. do Prado.

[GeoJSON de origen](https://github.com/CaiqueDourado/municipios-e-estados-do-brasil/blob/004b7cd546d158081dc3ca0956f0c9a89dcdcd3c/data/estados.geojson) · [Licencia de datos](https://github.com/CaiqueDourado/municipios-e-estados-do-brasil/blob/004b7cd546d158081dc3ca0956f0c9a89dcdcd3c/LICENSE-DATA.md) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) · [Avisos de terceros](https://github.com/CaiqueDourado/municipios-e-estados-do-brasil/blob/004b7cd546d158081dc3ca0956f0c9a89dcdcd3c/THIRD-PARTY-NOTICES.md)

### Aviso MIT de los campos base

```text
Copyright (c) Kelvin S. do Prado

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
