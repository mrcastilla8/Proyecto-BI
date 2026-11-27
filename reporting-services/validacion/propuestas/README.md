# Propuesta · Aviso de «Sin datos» en R02 y R04

[Parche](r02-r04-sin-datos.patch) preparado sobre [`88d0515`](https://github.com/mrcastilla8/Proyecto-BI/tree/88d051594892931701b32db3272ae8bee9e4ad5d). Los dos informes usan `CountRows(dataset)` para decidir si deben mostrar el aviso. En la consulta, el gran total puede devolver una fila aun cuando el filtro excluye todas las líneas. El parche añade `HAVING COUNT_BIG(*) > 0` al SQL de ambos informes y a su copia embebida en los RDL. Así, una consulta sin líneas puede activar el aviso existente y los grupos con datos conservan sus agregados.

```powershell
git apply --check reporting-services/validacion/propuestas/r02-r04-sin-datos.patch
git apply reporting-services/validacion/propuestas/r02-r04-sin-datos.patch
```

En Windows se comprobó que Git aplica el parche a los cuatro archivos del commit indicado y que el SQL versionado coincide literalmente con cada `CommandText` después de aplicarlo. Una fixture sintética en SQLite reprodujo la diferencia entre el agregado escalar vacío y el mismo agregado con la guarda. Queda por ejecutar los RDL sobre SQL Server en Report Builder y en el portal SSRS.

| Caso | Comprobación |
| --- | --- |
| Ambos informes, 01/01/2015–31/12/2015, filtros en «Todos» | Mostrar «Sin datos» y ocultar las tablas y gráficos sin filas. |
| Ambos informes, Desde 01/02/2017 y Hasta 01/01/2017 | Mostrar el aviso de rango invertido. |
| R02, 2017, filtros en «Todos» | Conservar 12 meses, R$ 5.962.902,01 y 43.428 pedidos entregados con ítems. |
| R04, histórico de `bed_bath_table` | Conservar los 9.272 pedidos distintos del subtotal de categoría y el desglose por producto. |

[Reglas de agrupación de SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql?view=sql-server-ver17) · [Evidencia R02](https://github.com/mrcastilla8/Proyecto-BI/pull/22) · [Conciliación R04](https://github.com/mrcastilla8/Proyecto-BI/pull/21)

## Correcciones preparadas sobre `8587b2c`

El [PR #23](https://github.com/mrcastilla8/Proyecto-BI/pull/23) incorporó R01 y R10 a `master`. Los tres parches siguientes se prepararon contra ese merge. Cada parche se puede comprobar con `git apply --check <archivo>` antes de aplicarlo desde la raíz del repositorio.

| Responsable | Entrega | Prueba en SQL Server y SSRS |
| --- | --- | --- |
| Poma | [R07 y R08](r07-r08-parametros-y-exportacion.patch). R07 ofrece «Todos» y los estados observados, y omite agregados vacíos. R08 rechaza espacios al inicio o al final en ambos datasets; mantiene el límite de 64 caracteres. Los valores monetarios y fechas mantienen el formato de presentación en el RDL con expresiones de valor tipadas. | R07 con pago cero, pago nulo y período sin pedidos. R08 con pedido multilínea, pedido sin ítems, ID inexistente, ID de 64 caracteres en fixture y variantes con espacios. Confirmar que precio y flete de línea se pueden sumar en Excel y revisar el tipo de la celda del pago agregado. |
| Castilla | [R01 y R10](r01-r10-formato-exportacion.patch). Conserva como valores sus ocho KPI tabulares de R01 y las fechas de ejecución de R10. Aplica el formato mediante `Style/Format`. | R01 histórico y SP con `ESNUMERO` para importes/conteos en la tabla. R10 con un lote `COMPLETE` y otro sin hora de fin para comprobar fecha y ausencia. Revisar por separado las tarjetas que reúnen título y valor en el mismo cuadro. |
| Basualdo | [Barra de R09](r09-barra-ventas.patch). Sustituye los glifos verticales por barras horizontales de imagen incrustada, con la proporción existente en 12 tramos y una marca gris cuando no hay datos. | Verificar en portal, PDF y Excel que el estado con el máximo llene la barra y otro estado muestre una longitud menor. Confirmar que se distingue sin datos de cero y que la columna monetaria sigue siendo numérica. |
| Cueva | Cuadrículas 2×2 en [R03](../../reports/R03_RankingVendedores.rdl) y [R05](../../reports/R05_EntregasRetrasadas.rdl) de este checkout. | Abrir Report Builder, comprobar los cuatro controles y conservar las selecciones al ejecutar. En R05, abrir R08 desde una fila y cotejar que la ficha corresponda al mismo pedido. |

En Windows pasaron `git apply --check` para los tres parches, el análisis XML de los cinco RDL parcheados, 29 comprobaciones de expresiones formateadas en R01/R07/R08/R10, la lectura de los 14 PNG de R09 y las comprobaciones de distribución 2×2 de R03/R05. Las cuatro consultas ajustadas en R07/R08 coinciden literalmente con su `CommandText`. La prueba sintética en SQLite cubrió 10 entradas de R08 y el selector de estados y pagos cero/nulos de R07. La generación de XLSX y el render de SSRS quedan pendientes en estos cambios.

### Pruebas del portal que pueden avanzar sin SSAS

1. Abrir el portal con rol `Browser`, comprobar que no permite publicar y verificar que un usuario sin acceso es rechazado. La identidad efectiva del origen compartido debe poder leer los datasets sin permisos DML. Registrar ambos resultados en `SSRS-02`.
2. Publicar las versiones revisadas bajo las rutas oficiales y verificar que los diez informes resuelven `BI_OLIST_DW`. Abrir las exportaciones del informe de humo y registrar el resultado de `PRE-G0-07`.
3. Ejecutar los casos funcionales para cada RDL contra el DW, validar las seis acciones internas `INT-02` y exportar y abrir diez PDF y diez XLSX. Registrar filtros, HEAD, fecha y resultados. Las conciliaciones finales contra DAX y las pruebas del PBIX Live se ejecutan con SSAS.

[Certificación](../../../docs/nivel-2/08_PRUEBAS_CERTIFICACION.md) · [Exportación a Excel](https://learn.microsoft.com/en-us/sql/reporting-services/report-builder/exporting-to-microsoft-excel-report-builder-and-ssrs?view=sql-server-ver17) · [Formato de valores](https://learn.microsoft.com/en-us/sql/reporting-services/report-design/expression-examples-report-builder-and-ssrs?view=sql-server-ver17)
