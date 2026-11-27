# M08 — integración, navegación y apoyo a P08

**Fecha:** 2026-11-27 · **HEAD probado:** `97fca9aaa073958b9ffb31101a7862133271cd01` · **Entorno:** SSRS 2022 Developer Native Mode local.

## Estado de las acciones SSRS

| Acción | Resultado observado | Estado |
|---|---|---|
| R01 → R02 | El vínculo abre R02 en el visor de SSRS | PASS |
| R01 → R09 | El vínculo abre R09 en el visor; el rango y estado de R01 se reflejan en la ejecución hija | PASS |
| R02 → R04 | Al expandir 2017 y activar “Ver categorías en R04” para enero, R04 abre con compra 01/01/2017–31/01/2017 y todas las categorías | PASS |
| R05 → R08 | El vínculo de una entrega abre la ficha. La cabecera y sus líneas se muestran sin guardar el OrderId en el manifiesto o el repositorio | PASS |
| R09 → R05 | El vínculo abre retrasos y conserva el período/estado; en la configuración histórica por defecto mostró 6.534 filas en 298 páginas | PASS |
| R09 → R06 | El vínculo abre satisfacción con los parámetros históricos del reporte padre | PASS |

R02 advierte que R04 no filtra por estado de cliente; el destino conserva el mes y categoría según el diseño de la acción, pero R04 muestra el universo completo para ese filtro. No se alteró ningún RDL ajeno para cambiar esa semántica.

Los diez informes están disponibles en `http://localhost/Reports` y el servicio responde en `http://localhost/ReportServer`. Las URL de acceso y ejecución quedaron registradas en [`manifiesto-urls.csv`](manifiesto-urls.csv); las rutas y hashes de los RDL están en [`manifiesto-publicacion.csv`](manifiesto-publicacion.csv). El R08 no incluye un ID en las URL guardadas: su parámetro obligatorio se captura dentro del portal.

## Apoyo a P08

- Se comprobaron en el servicio las diez rutas del catálogo y se preparó el manifiesto para configurar los accesos de P08.
- Power BI Desktop está instalado (`2.160.1151.0`), pero la comprobación no encontró un servicio SSAS registrado. No se abrió ni editó `powerbi/BI_OLIST.pbix`, no se probó la conexión Live ni los botones PBI; Ángel y Castilla conservan el PBIX maestro.
- Por tanto, la disponibilidad de los diez destinos SSRS está comprobada; el funcionamiento de los diez botones P08 y de los accesos P01–P07 sigue sin verificar.

## Reproducción de la navegación

1. Abrir `http://localhost/Reports` en el mismo equipo donde corre SSRS y usar la autenticación Windows de la sesión.
2. Entrar a R01; activar “Ir a R02” y “Ir a R09”.
3. En R02, expandir el año 2017 y activar “Ver categorías en R04” en un mes.
4. Entrar a R05 y activar el detalle de una fila; en R08 seleccionar un identificador válido solo dentro del portal.
5. En R09, probar “Ver entregas retrasadas (R05)” y “Ver satisfacción (R06)”.

`localhost` solo identifica el equipo donde corre el navegador; no se probó acceso remoto. Para una demostración desde otro equipo, Ángel/Castilla deben usar un nombre de host autorizado y comprobar autenticación, conectividad, TLS y las URL efectivas. No abrir SSRS a Internet.

## Límites del cierre

- Las verificaciones de seguridad del rol `Browser`, el rechazo de una cuenta no autorizada y la identidad SQL dedicada de solo lectura no se ejecutaron. La fuente compartida integrada sí resolvió consultas reales.
- La instalación no tiene servicio SSAS registrado; las pruebas Live y de botones del PBIX quedan fuera de este cierre.
- El gráfico de R09 sigue requiriendo corrección visual por Basualdo. No impide que el informe ejecute ni que sus medidas se lean.
- El detalle/exportaciones de R08 permanece solo en `validacion/salidas/`, ignorada por Git.
