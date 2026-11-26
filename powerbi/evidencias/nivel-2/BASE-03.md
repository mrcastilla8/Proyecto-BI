# BASE-03 · Cotejo SQL/DAX de la línea base (B01)

**Resultado `PASS`** · 26/11/2026, 15:33:19 (UTC−05:00, Lima) · Responsable `MarcosBasualdoAle` · HEAD `eaa652edf022d00d115e7604f86b1d99f905be2d`.

Windows 11 Pro (10.0.22621), SQL Server 2025 Enterprise Developer de 64 bits (17.0.1000.7), SSAS Tabular (17.0.25.218), Windows PowerShell (5.1.22621.4391) y ADOMD.NET (19.84.1.0). Se usó autenticación integrada de Windows en las conexiones locales a `BI_OLIST` y `BI_OLIST_Tabular`. Ambos servicios ya estaban en ejecución al comprobar el entorno.

El [comparador original](../../../ssas/validacion/Comparar-Metricas.ps1) ejecutó [SQL](../../../ssas/validacion/metricas.sql) y [DAX](../../../ssas/validacion/metricas.dax), verificó los nueve lotes `COMPLETE` de origen de la última publicación `DW.Transformacion` y devolvió código de salida `0`. Consultas independientes contaron 99.441 pedidos y 112.650 líneas en el DW, y comprobaron en `$SYSTEM.TMSCHEMA_MEASURES` que las ocho medidas publicadas coinciden por nombre con el contrato v1 y por expresión con `Model.bim`, normalizando saltos de línea y espacios en los extremos.

## Resultados por filtro

El comparador obtuvo 38 pares no vacíos y 18 pares SQL `NULL` / DAX `BLANK` coincidentes, con 56 pares evaluados. Aplicó igualdad exacta a los conteos y las sumas monetarias, y tolerancia absoluta de `1e-7` a los cocientes y promedios.

| Escenario | Filtro original | Pares no vacíos | Pares vacíos | Estado |
|---|---|---:|---:|---|
| `cancelados` | Estado `canceled` en ambos hechos | 2 | 6 | `PASS` |
| `cliente_sp` | Estado del cliente `SP` | 8 | 0 | `PASS` |
| `compra_2017` | Año 2017 en el rol activo de fecha de compra | 8 | 0 | `PASS` |
| `entrega_estimada_2017` | Año 2017 en la relación de fecha de entrega estimada de `FactPedidos` | 4 | 4 | `PASS` |
| `entrega_real_2017` | Año 2017 en la relación de fecha de entrega real de `FactPedidos` | 4 | 4 | `PASS` |
| `producto_y_vendedor_sp` | Categoría `cama_mesa_banho` y estado del vendedor `SP` | 4 | 4 | `PASS` |
| `total` | Sin filtro adicional | 8 | 0 | `PASS` |

La tabla muestra los agregados DAX que devolvió el comparador. Cocientes y promedios se muestran con diez decimales para lectura. El guion indica `BLANK` con su `NULL` SQL correspondiente.

| Escenario | Ventas (BRL) | Pedidos entregados con ítems | Pedidos totales | Ticket (BRL) | Flete (BRL) | Puntualidad (proporción) | Días promedio | Calificación |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `cancelados` | — | — | 625 | — | — | — | — | 1,8000000000 |
| `cliente_sp` | 5.067.633,16 | 40.501 | 41.746 | 125,1236552184 | 702.069,99 | 0,9550550699 | 8,7613859961 | 4,1741255136 |
| `compra_2017` | 5.962.902,01 | 43.428 | 45.101 | 137,3054713549 | 958.633,23 | 0,9435131027 | 13,0255266811 | 4,0874968310 |
| `entrega_estimada_2017` | — | — | 40.317 | — | — | 0,9460079969 | 12,5816730516 | 4,0989253758 |
| `entrega_real_2017` | — | — | 40.930 | — | — | 0,9569508918 | 12,2333429625 | 4,2141357211 |
| `producto_y_vendedor_sp` | 898.137,09 | 8.214 | — | 109,3422315559 | 171.911,05 | — | — | — |
| `total` | 13.221.498,11 | 96.478 | 99.441 | 137,0415857501 | 2.198.275,64 | 0,9322690992 | 12,5582170981 | 4,0867934146 |

## Reproducción en Windows

Desde la raíz del repositorio, abre Windows PowerShell 5.1 con una cuenta Windows autorizada a leer `dw`, `audit.Batch` y el catálogo Tabular. Mantén la misma publicación del DW y de SSAS durante el cotejo. Introduce el destino SQL local, el destino SSAS de loopback con el puerto configurado y la carpeta local de ADOMD.NET para .NET Framework. En esta ejecución se usó `-ConfiarCertificadoSql` para el certificado de la instancia SQL local del laboratorio.

```powershell
$sql = Read-Host 'Destino SQL Server local'
$tabular = Read-Host 'Destino SSAS local con puerto configurado'
$adomd = Read-Host 'Carpeta de Microsoft.AnalysisServices.AdomdClient.dll'
./ssas/validacion/Comparar-Metricas.ps1 -ServidorSql $sql -ServidorTabular $tabular `
    -CarpetaAdomd $adomd -BaseTabular BI_OLIST_Tabular -ConfiarCertificadoSql
```

La resolución por nombre de instancia SSAS devolvió `A connection cannot be made to redirector. Ensure that 'SQL Browser' service is running.` Se usó la conexión directa por loopback con SQL Browser detenido. Con esa conexión, PowerShell 7.6.9 y la biblioteca ADOMD instalada devolvieron `Could not load type 'System.Runtime.Remoting.Messaging.CallContext'` al cargar `mscorlib` 4.0.0.0. La repetición en Windows PowerShell 5.1 ejecutó el script de solo lectura completo.

La prueba cubre los siete filtros históricos en SQL Server y el catálogo SSAS publicado. La conexión de Power BI Desktop, los informes SSRS y los demás casos de certificación se verifican en pruebas propias.
