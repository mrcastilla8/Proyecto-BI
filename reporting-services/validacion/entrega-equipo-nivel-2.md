# Entrega al equipo · OLIST 360° Nivel 2

**27 de noviembre de 2026.** El [PR #23](https://github.com/mrcastilla8/Proyecto-BI/pull/23) incorporó `P01`, `P08`, `R01` y `R10`. La base de esta entrega es [`8587b2c`](https://github.com/mrcastilla8/Proyecto-BI/tree/8587b2c5decb9ec952867e1150b4f25e79484813). En esa revisión están las 15 páginas como entregas individuales y los 10 RDL. Ángel tiene a cargo reunir las páginas en el PBIX maestro. El [PR #22](https://github.com/mrcastilla8/Proyecto-BI/pull/22) documenta seis informes publicados y exportados en el portal de Poma. `R01` y `R10` también tienen pruebas en el entorno local de Castilla.

## Qué entregamos y quién continúa

| Responsable | Archivos entregados | Siguiente comprobación |
| --- | --- | --- |
| **Castilla** | [Parche de formato de exportación para R01 y R10](propuestas/r01-r10-formato-exportacion.patch). Conserva los valores de los ocho KPI de la tabla de R01 y las fechas de R10 como expresiones tipadas y aplica el formato en el RDL. | Abrir PDF y XLSX en SSRS. Comprobar que Excel reconoce importes y conteos como números y fechas como fechas. Cerrar la aprobación de la plantilla y consolidar el informe académico con las evidencias de ambos niveles. |
| **Ángel** | [Parche de R02 y R04 para rangos sin datos](propuestas/r02-r04-sin-datos.patch). Evita que un total vacío oculte el aviso del informe. | Probar los rangos vacío, invertido y con datos. Comprobar `R02 → R04`. Integrar las 8 páginas principales, los 4 tooltips y los 3 drill-through en el PBIX maestro y probar los botones con las URLs de Poma. |
| **Basualdo** | [Mapa TopoJSON de 27 UF](../../powerbi/validacion/pbi-08/brasil-uf.topojson) con [guía y atribución](../../powerbi/validacion/pbi-08/README.md). [Parche de barras horizontales para R09](propuestas/r09-barra-ventas.patch). | Cargar el mapa en P07 y comprobar el filtro `2017 + SP` y las claves de región en Live. Verificar en portal, PDF y Excel la barra de R09 y sus saltos a R05/R06. |
| **Poma** | [Parche de parámetros y exportación para R07 y R08](propuestas/r07-r08-parametros-y-exportacion.patch). R07 usa estados observados y separa pago cero de pago ausente. R08 valida longitud y espacios en cabecera y detalle. | Probar R07/R08 en Report Builder. Completar el catálogo de demo con R01, R03, R05 y R10. Después de aplicar las correcciones aceptadas, generar los 10 PDF y 10 XLSX, y comprobar los permisos efectivos del origen compartido y del portal. |
| **Cueva** | Cuadrículas 2×2 ya incorporadas en [R03](../reports/R03_RankingVendedores.rdl) y [R05](../reports/R05_EntregasRetrasadas.rdl). [Cotejo X06](revision-sql-x06.md) de 34 consultas y seis acciones entre informes. | Abrir R03/R05 en Report Builder, comprobar los cuatro controles, ejecutar `SSRS-05` y `SSRS-07`, y verificar con Poma la ficha de pedido abierta por `R05 → R08`. Con Ángel, repetir los casos `PBI-05` y `PBI-06` en el maestro. |

Cada responsable puede aplicar su parche desde la raíz del repositorio sobre una rama actualizada. La [guía de propuestas](propuestas/README.md) incluye el comando de comprobación, las entradas de prueba y los resultados esperados. El mapa puede cargarse desde el archivo local en el visual de Power BI.

## Orden para completar la entrega

1. **SQL Server y SSRS.** Abrir los informes modificados en Report Builder con el DW. Verificar autenticación, permisos de solo lectura y exportaciones de humo. Completar el catálogo de diez informes, probar las seis acciones entre ellos y abrir cada PDF y XLSX en el equipo de demo. Estas pruebas se pueden ejecutar mientras se integra Power BI.
2. **Power BI Live.** Integrar las 15 páginas en el PBIX maestro, cargar el mapa en P07, comprobar filtros sincronizados y contexto de tooltips y drill-through, y probar los accesos a los RDL desde `P01`–`P08` con las URLs efectivas.
3. **Certificación.** Reunir las evidencias en la [matriz oficial de 29 casos](../../docs/nivel-2/08_PRUEBAS_CERTIFICACION.md), completar la conciliación contra DAX, ensayar la demo en el mismo equipo y actualizar el informe académico. El [issue #6](https://github.com/mrcastilla8/Proyecto-BI/issues/6) sigue siendo el punto de seguimiento del informe reproducible.

## Verificación registrada

- `python scripts/validar_base.py` y `python -m unittest discover -s scripts -p 'test_*.py'` pasaron en Windows con Python 3.14.8. La segunda ejecución cubrió 14 pruebas.
- `python reporting-services/validacion/comprobar_r03_r05.py` pasó 10 comprobaciones sintéticas. Se comprobó por XML que cada cuadrícula nueva contiene los cuatro parámetros y que el resto del RDL coincide con la base.
- `git apply --check` se ejecutó contra copias de los archivos de `master`. Pasaron el análisis XML de los RDL, el cotejo de las cuatro consultas modificadas en R07/R08, 29 comprobaciones de formato, 10 casos sintéticos de `OrderId` y la validación de 14 imágenes incrustadas de R09.
- El TopoJSON contiene 27 claves únicas y 36 anillos cerrados. La conversión conservó los vértices a la precisión de la fuente. La [guía del mapa](../../powerbi/validacion/pbi-08/README.md) registra la fuente y la licencia.

Los resultados anteriores corresponden a comprobaciones locales de archivos y fixtures. El render de estas correcciones en Report Builder y SSRS, la comprobación de los XLSX publicados y la prueba del mapa en Power BI Live requieren el entorno de demostración.
