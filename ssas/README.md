# SSAS Tabular
Responsable Basualdo (`@MarcosBasualdoAle`). Rama `basualdo/ssas-tabular`. [Issue #4](https://github.com/mrcastilla8/Proyecto-BI/issues/4)

Abre [BI_OLIST_Tabular.slnx](BI_OLIST_Tabular/BI_OLIST_Tabular.slnx) en Visual Studio con Analysis Services Projects. El proyecto usa el nivel de compatibilidad 1700 de SQL Server Analysis Services 2025 y el modo Import de SSAS. Power BI se conecta en vivo al catálogo publicado en SSAS.

## Modelo y filtros

- Ocho tablas de `BI_OLIST.dw` y once relaciones de dimensión a hecho. `FactPedidos` tiene una fila por pedido y `FactDetallePedido` una por ítem. Producto, vendedor y geografía del vendedor filtran el detalle. Cliente, geografía del cliente y fecha de compra filtran ambos hechos.
- `DimFecha` usa la fecha de compra como rol activo. Las pruebas de entrega activan cada rol alternativo por separado con `USERELATIONSHIP`. El miembro `-1` conserva fecha vacía. Las jerarquías cubren calendario, producto y las dos geografías.
- Los ocho nombres de medida coinciden con el [contrato de métricas](../contracts/metricas.v1.json). La puntualidad compara los días calendario real y estimado. La duración conserva la fracción del día y la calificación promedia una nota consolidada por pedido. Los importes usan BRL.

[Captura del diagrama y las medidas en Visual Studio](evidencias/diagrama-tabular.png)

## Desplegar y comprobar

1. Usa una publicación conciliada de `BI_OLIST.dw` con los nueve lotes auténticos. La [entrega de ingesta](../ssis/ingesta/HANDOFF_AXEL.md) identifica los lotes de origen. El [procedimiento de transformación](../ssis/transformaciones/README.md) incluye la consulta para cotejar staging y DW.
2. Configura el nombre del servidor SQL y el destino Tabular local como parámetros. El procesamiento usa MSOLEDBSQL19 con autenticación integrada. La identidad de procesamiento de SSAS necesita lectura sobre `dw`. La cuenta que ejecuta el cotejo SQL necesita lectura de `dw` y `audit.Batch`.
3. Ejecuta los scripts en PowerShell 7 con las bibliotecas TOM y ADOMD de la extensión de Visual Studio. Asigna a `$sql` y `$tabular` los destinos locales verificados. Usa `-ConfiarCertificadoSql` en el laboratorio local si confirmaste que la instancia usa un certificado autofirmado.

   ```powershell
   $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
   $visualStudio = & $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath
   $carpetaSsas = Join-Path $visualStudio 'Common7/IDE/CommonExtensions/Microsoft/SSAS'
   ./ssas/validacion/Publicar-Modelo.ps1 -ServidorSql $sql -ServidorTabular $tabular -CarpetaTom $carpetaSsas
   ./ssas/validacion/Comparar-Metricas.ps1 -ServidorSql $sql -ServidorTabular $tabular -CarpetaAdomd $carpetaSsas
   python scripts/validar_base.py
   ```

El script crea el catálogo `BI_OLIST_Tabular` y lo procesa en una transacción SSAS. Tras corregir un fallo, repite el mismo comando. Si el catálogo ya contiene una publicación de este proyecto y se confirma su reemplazo, usa `-Actualizar` para actualizarlo y reprocesarlo en la misma transacción. Mantén estable la publicación del DW durante el procesamiento y el cotejo.

El cotejo ejecuta [SQL](validacion/metricas.sql) y [DAX](validacion/metricas.dax) para el total, compra en 2017, clientes de SP, categoría y vendedores de SP, cada rol de fecha de entrega en 2017 y pedidos cancelados. Comprueba los valores vacíos, usa igualdad exacta para conteos e importes sumados y una tolerancia absoluta de `0,0000001` para los cocientes y promedios.

## Evidencia con datos auténticos del 20-11-2026

- La [publicación de Olist en Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), versión 2, declara la licencia CC BY-NC-SA 4.0. Los nueve SHA-256 coincidieron con el [perfil de Poma](../ssis/ingesta/evidencias/informe/anexo-b/perfil-autentico.json).
- Visual Studio 2026 18.10.2 compiló ambos proyectos SSIS. Su depurador ejecutó el maestro de ingesta en LocalDB 17.0.4025.3 y dejó nueve lotes `COMPLETE`, 1.550.922 filas aceptadas y cero rechazadas. El DTExec instalado con SQL Server devolvió `0xC0010026` al intentar cargar la tarea Script del maestro. El depurador de Integration Services de Visual Studio sí cargó esa tarea.
- El DTExec x64 17.0.1000.7 ejecutó la transformación dos veces con código 0, en 20,5 s y 13,3 s. `ssis/transformaciones/sql/conciliar.sql` verificó 99.441 pedidos y 112.650 líneas. Las ocho huellas del DW coincidieron entre ejecuciones y en la copia restaurada en SQL Server 2025 Enterprise Developer. La cuenta del servicio SSAS recibió lectura del esquema `dw`.
- MSBuild compiló el proyecto Tabular con cero advertencias y errores. El despliegue y procesamiento se verificaron en una instancia persistente de SSAS Tabular 17.0.25.218 con MSOLEDBSQL19. Se confirmó la conexión a un puerto fijo local con SQL Server Browser deshabilitado, las ocho particiones en estado `Ready` y las once relaciones unidireccionales, dos de ellas inactivas.
- `Comparar-Metricas.ps1` comprobó los siete escenarios, con 38 valores no vacíos y 18 vacíos coincidentes. La republicación con `-Actualizar` produjo los mismos resultados. `python scripts/validar_base.py` y las 14 pruebas de validación base pasaron.

| Métrica en el total | Resultado |
| --- | ---: |
| Ventas de productos entregados | R$ 13.221.498,11 |
| Pedidos entregados con ítems | 96.478 |
| Pedidos totales | 99.441 |
| Ticket promedio de productos entregados | R$ 137,04 |
| Flete de pedidos entregados | R$ 2.198.275,64 |
| Entregas a tiempo | 93,23 % |
| Días promedio de entrega | 12,56 |
| Calificación promedio | 4,09 |
