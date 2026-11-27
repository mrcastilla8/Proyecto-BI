# Handoff de Reporting Services para Ángel y Castilla

**Corte:** 2026-11-27 · **Rama:** `poma/nivel-2-reporting` · **Responsable del handoff:** Poma.

## Estado local

- SSRS Native está operativo en el equipo donde se ejecutó el cierre. Portal: `http://localhost/Reports`; servicio: `http://localhost/ReportServer`.
- El catálogo contiene diez informes definitivos bajo `/OLIST360`, enlazados al origen compartido `/OLIST360/DataSources/BI_OLIST_DW` y a `BI_OLIST`.
- Se verificó render y exportación PDF/XLSX de R01–R10. Los manifiestos detallan rutas, parámetros de prueba y SHA-256: [`manifiesto-publicacion.csv`](manifiesto-publicacion.csv), [`manifiesto-urls.csv`](manifiesto-urls.csv).
- Se probaron las navegaciones R01→R02/R09, R02→R04, R05→R08 y R09→R05/R06. El vínculo R02→R04 conserva el período, pero no filtra por estado de cliente; el informe padre muestra la advertencia correspondiente.
- Las veinte exportaciones y los resultados están descritos en [`RESULTADOS_M06_M07.md`](RESULTADOS_M06_M07.md). Los archivos completos están en `validacion/salidas/`, carpeta ignorada por Git. La evidencia R08 conserva detalle de un pedido y no debe trasladarse al repositorio.

## Destinos para P08

Usar `manifiesto-urls.csv` para configurar las URL aprobadas dentro del PBIX. Cada destino se probó desde el servicio local. La fila R08 deliberadamente solo incluye la URL del portal; `OrderId` se captura dentro del informe y no debe persistirse como parámetro de URL.

`localhost` solo resuelve en el equipo que ejecuta el navegador/Power BI. Para una demostración en otro equipo, Ángel/Castilla deben sustituirlo por el host privado autorizado, comprobar autenticación Windows, resolución de nombre, conectividad y TLS, y volver a probar los diez botones. No abrir SSRS a Internet ni publicar credenciales.

## Comprobaciones pendientes en el PBIX maestro

Ángel, como custodio del PBIX, debe probar en una copia de trabajo o durante la integración controlada:

1. Conexión Live a SSAS y apertura de P08; la sesión de cierre no encontró un servicio SSAS registrado.
2. Cada botón de P08 abre el RDL de la fila correspondiente de `manifiesto-urls.csv`.
3. Parámetros admitidos, navegación de regreso y enlace al portal SSRS.
4. Reemplazo de `localhost` solo si se acuerda un host de demo y se valida desde ese equipo.
5. Que la configuración no introduzca cambios al PBIX maestro atribuibles a Poma ni altere el modelo/DAX.

Las URL verificadas no prueban los botones del PBIX; por eso `INT-01` global permanece sin certificar.

## Parámetros y reproducción

Los valores de prueba no son valores predeterminados para todos los usuarios. Las fechas, filtros, estado y TopN utilizados por informe están en `manifiesto-urls.csv`. Para revisar el catálogo y repetir exportaciones desde Windows, usar los comandos de [`CIERRE_POMA.md`](CIERRE_POMA.md) y [`README.md`](../README.md). El origen comparte autenticación integrada local; no se probó una identidad dedicada de solo lectura ni roles restringidos.

## Resultado visual y responsables

- R09 ejecuta y sus métricas tabulares se leen, pero el gráfico “Ventas vs. máximo” se muestra con glifos verticales repetidos. Corresponde a Basualdo revisar/corregir este elemento visual.
- R08 produce una cabecera y dos líneas para el caso válido; las exportaciones detalladas se mantienen locales.
- El humo PRE_G0_Humo se exportó/revisó y se retiró del catálogo; solo quedan R01–R10 y el origen compartido.
- Los archivos fuente de SSRS y evidencias están en `reporting-services/`; la matriz completa el corte actual en [`matriz.csv`](matriz.csv). El informe de cierre registra los límites de M01–M08.
