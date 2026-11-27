# Cierre de responsabilidades Poma — OLIST 360° Nivel 2

**Fecha del corte:** 2026-11-27 · **Rama:** `poma/nivel-2-reporting` · **HEAD probado para ejecuciones:** `97fca9aaa073958b9ffb31101a7862133271cd01` (`97fca9a`). Este documento cubre M01–M08 del componente Poma; no declara certificada toda la solución Nivel 2.

## Resultado por responsabilidad

| Tarea | Estado inicial | Acción realizada | Estado al cierre |
|---|---|---|---|
| M01 — infraestructura | SSRS/catálogo instalados y usados en el corte previo | Verificación actual del servicio, catálogos, portal y SOAP | PASS |
| M02 — portal/origen y seguridad | Origen integrado en `/OLIST360/DataSources/BI_OLIST_DW` | Confirmado HTTP/SQL y ejecución real; no se auditaron roles ni identidad SQL de solo lectura | PARCIAL |
| M03 — plantilla | Plantilla disponible | Revalidación del RDL y referencia de origen compartido | PASS |
| M04 — R07 | Primera prueba ejecutada | Pruebas de rango, pagos, nulos, cero y estados; exportaciones 10/10 | PASS |
| M05 — R08 | Pruebas de existente/inexistente del corte previo | Revalidación de existente con varias líneas, inexistente, sin líneas y guardas de parámetro; detalle solo local | PASS |
| M06 — publicar diez RDL | Seis informes publicados en el corte histórico | Diez rutas definitivas confirmadas por API y diez informes ejecutados | PASS (10/10) |
| M07 — diez PDF y diez XLSX | Seis pares del corte histórico | Veinte exportaciones verificadas; PDF inspeccionados y XLSX abiertos en Excel | PASS exportaciones; FAIL visual específico de R09 |
| M08 — integración y demo | Acciones RDL parcialmente verificadas | Se probaron seis enlaces RDL; se generaron URL y handoff para P08 | PASS navegación RDL local; BLOCKED botones PBI/Live |

## Entorno actual

- Windows 11 Home build 26300, 64 bits.
- SQL Server Developer `17.0.1000.7`; `BI_OLIST` ONLINE y tablas de hechos requeridas presentes.
- `SELECT` de verificación: `dw.FactPedidos` 99.441 filas, `dw.FactDetallePedido` 112.650, `audit.Batch` 10 y `audit.Reject` 0. `audit.Batch` cubre 20/11/2026–26/11/2026 con diez lotes `COMPLETE`. Dimensiones presentes: `DimCliente`, `DimFecha`, `DimGeografiaCliente`, `DimGeografiaVendedor`, `DimProducto` y `DimVendedor`.
- SSRS Developer Native Mode; entrada instalada `16.0.9819.33617`; servicio `SQLServerReportingServices` `Running`/inicio automático.
- `ReportServer` y `ReportServerTempDB` ONLINE. `http://localhost/Reports`, `http://localhost/ReportServer` y `ReportService2010` respondieron HTTP 200.
- Report Builder `15.1.30001.02`; Excel abrió los diez libros. Excel sigue mostrando una advertencia de activación, sin impedir lectura.
- Power BI Desktop `2.160.1151.0` está instalado; la verificación no encontró un servicio SSAS registrado. No se abrió ni modificó el PBIX maestro.
- `WIN-02` aparece `BLOCKED` porque el proceso de verificación no está elevado. No hubo que instalar ni configurar servicios en esta ejecución.

## Informes y pruebas destacadas

- R07 observó 162 agregados, 99.441 pedidos, 99.440 pedidos con pago y uno sin pago; total de pagos observados **R$ 16.008.872,12**. En el rango de cancelados se observaron 625 pedidos y **R$ 143.255,60**; existen tres pedidos con pago observado igual a cero. El caso sin pago conserva `NULL`, no se convierte silenciosamente a cero.
- R08 produjo una cabecera con dos líneas y pago agregado; un identificador inexistente devolvió cero cabeceras y cero líneas; un pedido real sin líneas devolvió una cabecera y cero filas de detalle. Se rechazaron vacío, espacios exteriores y longitud inválida; el ID empleado se mantiene en memoria/local y no se escribe en Git, manifiestos ni URL.
- El control estricto de espacios de `R08_Cabecera.sql`, `R08_Detalle.sql` y el RDL usa `DATALENGTH(@OrderId)=DATALENGTH(LTRIM(RTRIM(@OrderId)))` junto con la guarda de longitud. El caso con espacios finales que pasaba la validación anterior ahora no devuelve coincidencia.
- Diez RDL, veinte exportaciones. Se renderizaron 62 páginas PDF. R09 ejecuta y sus cifras se leen, pero el gráfico “Ventas vs. máximo” aparece como glifos verticales repetidos; su corrección corresponde a Basualdo.
- El humo volvió a publicarse tras ajustar el ancho imprimible. PDF: una página, conteos 99.441/112.650, SHA-256 `CD02F104E921F93123EBBF1CE3284D83984497525486B757E0A467AC21AB09F9`. XLSX abierto en Excel, SHA-256 `C090E8C5CD7865FC663417A5C44ABA914B851C45240D3D77DC9B98F66B9C39BC`. Después se retiró solo `/OLIST360/Pruebas/PRE_G0_Humo` por `ReportService2010.DeleteItem`; quedaron los diez informes, el catálogo y el origen compartido.
- RDL/exportaciones, parámetros y hashes: [`RESULTADOS_M06_M07.md`](RESULTADOS_M06_M07.md). Casos de navegación: [`RESULTADOS_M08.md`](RESULTADOS_M08.md). Entrega a Ángel y Castilla: [`HANDOFF_INTEGRACION.md`](HANDOFF_INTEGRACION.md). Matriz: [`matriz.csv`](matriz.csv). Manifiestos: [`manifiesto-publicacion.csv`](manifiesto-publicacion.csv) y [`manifiesto-urls.csv`](manifiesto-urls.csv).

## Integración y límites

Se probaron R01→R02, R01→R09, R02→R04, R05→R08 y R09→R05/R06. El enlace R02→R04 conserva mes y categoría; R02 advierte que el estado de cliente no filtra R04. Las diez URLs SSRS están disponibles en el manifiesto; esto verifica los destinos, no los botones del PBIX.

Quedan sin evidencia: rol `Browser` restringido y rechazo de una cuenta no autorizada; identidad dedicada del origen con mínimo `SELECT`; botones P08/P01–P07; conexión Live a SSAS y ensayo de la demo en otro equipo. No se marca `SSRS-02`, `INT-01` global ni `INT-03` como PASS. La certificación G3/G4 total corresponde a Castilla y a cada responsable de componente.

## Reproducción y rollback

Desde la raíz del repositorio, en Windows:

```powershell
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test_*.py' -v
.\reporting-services\scripts\Verificar-CatalogoSSRS.ps1 `
  -SqlServerInstance localhost `
  -PortalUrl http://localhost/Reports `
  -ReportServerUrl http://localhost/ReportServer `
  -TrustServerCertificate
.\reporting-services\scripts\Exportar-VerificarNivel2.ps1 `
  -SqlServerInstance localhost `
  -ReportServerUrl http://localhost/ReportServer `
  -OutputDirectory .\reporting-services\validacion\salidas\cierre-poma-2026-11-27 `
  -TrustServerCertificate
git diff --check
```

Para revertir un cambio de RDL, republicar desde Report Builder o `ReportService2010.SetItemDefinition` la última definición validada. Para revertir el ajuste local de humo, restaurar el RDL desde Git y republicarlo solo si se acepta volver a la versión de impresión anterior. No eliminar `BI_OLIST`, los catálogos ni sus tablas; no reconstruir el servidor como rollback.

El PR permanece Draft hasta que los checks requeridos estén verdes. No se creó ningún issue y no se hizo merge.
