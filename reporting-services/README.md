# SSRS 2022 Native Mode — OLIST 360° (M01–M08, 10/10 informes)

Esta entrega usa SSRS 2022 Developer Native Mode, el catálogo local, el portal y el origen compartido a `BI_OLIST`; publica y ejecuta los diez RDL. M04–M08 y el cierre del humo están documentados en [`validacion/CIERRE_POMA.md`](validacion/CIERRE_POMA.md), con resultados de navegación en [`validacion/RESULTADOS_M08.md`](validacion/RESULTADOS_M08.md). No configura SSAS ni modifica Power BI, SSIS, `database/`, contratos o `Model.bim`.

## Resultado de esta máquina

El corte histórico de infraestructura está en [`validacion/RESULTADOS_M01_M02.md`](validacion/RESULTADOS_M01_M02.md); el corte parcial de seis informes se conserva en [`validacion/RESULTADOS_M06_M07.md`](validacion/RESULTADOS_M06_M07.md), seguido por la validación completa 10/10. La matriz y los manifiestos vigentes están en `validacion/`; el índice de evidencias está en [`evidencias/INDICE.md`](evidencias/INDICE.md). Los casos de seguridad no comprobados permanecen sin PASS.

## Requisitos y límites

- Windows de escritorio compatible, permisos de administrador local para instalar/configurar servicios, SQL Server Developer para el catálogo y el DW, y espacio libre suficiente.
- **SQL Server 2022 Reporting Services (SSRS), edición Developer, modo nativo**. La comprobación actual detecta SSRS `16.0.9819.33617` en Windows; el servicio está `Running`, `ReportServer` y `ReportServerTempDB` están `ONLINE`, y portal y WSDL responden HTTP 200 en `http://localhost`. No sustituir por Power BI Report Server.
- Microsoft Report Builder `15.1.30001.02` está instalado. Para navegar en Brave usa `http://localhost/Reports`; la IP `127.0.0.1` puede abrir un diálogo de credenciales.
- Report Builder para editar/publicar el RDL. La extensión de Reporting Services para Visual Studio es opcional.
- `BI_OLIST` con el esquema dimensional cargado. Esta entrega no instala/configura SSAS ni cambia el PBIX.
- Mantener URLs ligadas a loopback o a una LAN privada autorizada. No abrir puertos al público. HTTP se admite únicamente en laboratorio local; usar TLS si el portal será accesible desde otro equipo.

## M01 — instalación y configuración del servidor

1. Descargue SSRS desde el [Centro oficial de descargas de Microsoft](https://www.microsoft.com/es-mx/download/details.aspx?id=104502), revise la firma Authenticode y elija **Developer** en el instalador. Complete la instalación y abra **Reporting Services Configuration Manager** con elevación.
2. Conecte el Configuration Manager a la instancia SSRS recién instalada. En **Service Account**, configure una cuenta de servicio soportada. No cambie la cuenta de SQL Server Database Engine.
3. En **Database**, elija *Change Database* → *Create a new report server database*. Conecte a la instancia de SQL Server Developer que aloja `BI_OLIST`; seleccione modo nativo y nombres `ReportServer` / `ReportServerTempDB`. Deje que el asistente cree y configure el catálogo. Nunca cree ni edite manualmente sus tablas.
4. En **Web Service URL** y **Web Portal URL**, elija puertos disponibles. Conserve las URLs efectivas que muestre el asistente; páselas como parámetros al verificador. Para esta entrega, pruebe solo URLs de loopback, así el verificador no envía credenciales Windows a otra máquina.
5. Compruebe que abre el portal y el WSDL `ReportService2010.asmx?wsdl` con la cuenta Windows administradora. Configure el firewall solo para loopback o la LAN privada acordada. Guarde una copia de la clave de cifrado fuera del repositorio si corresponde.
6. Instale Report Builder desde Microsoft. Su versión exacta y las URLs reales se registran en la evidencia `EVD-SSRS-01`/`03`.

Si SSRS aún no está instalado, `Verificar-Entorno.ps1` lo mostrará como bloqueado; no intente publicar el RDL hasta que el servicio, catálogo y portal estén listos.

## M02 — portal, seguridad y fuente de datos

1. Use la cuenta Windows local que ejecuta SSRS para administrar el portal y publicar durante la exposición académica; no se crean usuarios ni pruebas de roles adicionales.
2. Cree `/OLIST360`, `/OLIST360/Pruebas`, `/OLIST360/02_Comercial`, `/OLIST360/03_Operaciones` y `/OLIST360/DataSources`.
3. Cree `/OLIST360/DataSources/BI_OLIST_DW`, proveedor Microsoft SQL Server, base `BI_OLIST`; configure Windows Integrated Security para la conexión local a la instancia que aloja `BI_OLIST`. El nombre del servidor y las credenciales no se guardan en Git.
4. Guarde el origen y use `Test Connection`. El humo y R07/R08 referencian este origen compartido.

## Prueba temporal de humo PRE-G0-06/07

1. Antes de publicar, ejecute la validación estática:

   ```powershell
   .\reporting-services\scripts\Validar-RDLHumo.ps1
   ```

   El `CommandText` debe coincidir exactamente con [`datasets/PRE_G0_Humo.sql`](datasets/PRE_G0_Humo.sql), usar `BI_OLIST_DW` y consultar solo conteos agregados.
2. En Report Builder, abra [`pruebas/humo/PRE_G0_Humo.rdl`](pruebas/humo/PRE_G0_Humo.rdl), compruebe la referencia de origen `/OLIST360/DataSources/BI_OLIST_DW` y publíquelo temporalmente en `/OLIST360/Pruebas/PRE_G0_Humo`.
3. Ejecute `Verificar-CatalogoSSRS.ps1` con las URLs efectivas y confirme servicios/catálogos/HTTP. En la instalación local documentada, use `-TrustServerCertificate` porque el SQL de desarrollo presenta un certificado no confiable para el cliente de prueba. Ejecute la prueba desde el portal. En el cierre 2026-11-27 se observaron 99.441 pedidos y 112.650 líneas.
4. Exporte desde el portal a PDF y Excel (`EXCELOPENXML`). Opcionalmente, use `Exportar-VerificarHumo.ps1` con la URL del Web Service y `-OutputDirectory` en una carpeta local. Comprueba HTTP, firma PDF/ZIP XLSX y SHA-256, y guarda los archivos en esa carpeta. La excepción de autenticación HTTP de PowerShell 7 solo se habilita después de comprobar que el endpoint es loopback.
5. Registre resultado, URL real, fecha, HEAD y hash local en `validacion/matriz.csv`/`evidencias/INDICE.md`. Redacte capturas para que no muestren identidad Windows, credenciales ni datos de pedidos.
6. Retire solo `/OLIST360/Pruebas/PRE_G0_Humo` mediante el portal o la API oficial al cerrar la prueba. Conserva el origen compartido y el catálogo. En este cierre el informe temporal ya fue retirado tras verificar ambas exportaciones.

## M03–M05 — plantilla, R07 y R08

- `diseno/Plantilla_OLIST360.rdl`: base visual reutilizable OLIST 360°, A4 horizontal, cabecera, filtros, tarjetas KPI y área de detalle.
- `reports/R07_ImportesPagados.rdl`: parámetros `Desde`, `Hasta` y `EstadoPedido`; importes y conteos por mes/estado/total, sin convertir `NULL` a cero ni presentar el resultado como ingreso neto.
- `reports/R08_FichaPedido.rdl`: `OrderId` obligatorio; cabecera y detalle separados, nulos visibles, estados para pedido inexistente/sin ítems y montos de línea separados del pago agregado. La guarda de ID rechaza espacios exteriores además de vacíos y valores sobrelongitud.
- Las consultas SQL en `datasets/` siguen `docs/nivel-2/06_CONTRATO_CONSULTAS_SQL.md`. Los diez RDL están publicados y sus rutas/hashes están en `validacion/manifiesto-publicacion.csv`.

## M06–M08 — publicación, exportación e integración

- El catálogo `/OLIST360` contiene diez informes; los diez se ejecutaron desde el servicio y generaron PDF y XLSX en una carpeta local ignorada por Git.
- Los 62 folios PDF se renderizaron y revisaron. R09 conserva una limitación visual: “Ventas vs. máximo” aparece como glifos verticales repetidos; la ejecución y las métricas tabulares son legibles. El informe pertenece a Basualdo y el arreglo queda en su alcance.
- Los diez libros XLSX se abrieron en Excel. Excel mostró “Error de activación de productos”, pero permitió ver el contenido.
- Se confirmó navegación R01→R02, R01→R09, R02→R04, R05→R08 y R09→R05/R06. El enlace R02→R04 conserva el mes y R04 no conserva el filtro de estado de cliente; el destino lo advierte.
- Las diez URLs locales están en `validacion/manifiesto-urls.csv`. El botón P08 del PBIX maestro no se probó ni se modificó; el [handoff de integración](validacion/HANDOFF_INTEGRACION.md) deja explícita esa diferencia y las comprobaciones que corresponden a Ángel/Castilla.
- Las exportaciones completas y las vistas de R05/R08 permanecen locales; `validacion/salidas/` está ignorado por Git. No se versiona el identificador de prueba ni el detalle de R08.

## Comandos de preflight

Ejecutar desde la raíz del repositorio en Windows PowerShell 5.1 o posterior. Los validadores no hacen cambios en SQL.

```powershell
.\reporting-services\scripts\Verificar-Entorno.ps1 -SqlServerInstance '<instancia SQL local>'
.\reporting-services\scripts\Verificar-CatalogoSSRS.ps1 `
  -SqlServerInstance '<instancia SQL local>' `
  -PortalUrl '<URL de loopback del portal>' `
  -ReportServerUrl '<URL de loopback del servicio>' `
  -TrustServerCertificate
.\reporting-services\scripts\Validar-RDLHumo.ps1
```

Los scripts devuelven filas `PASS`, `FAIL` o `BLOCKED`; los checks no ejecutados permanecen `NOT_RUN`. En este equipo el SQL local usa un certificado no confiable por el cliente de prueba; `-TrustServerCertificate` se limita a esa conexión del verificador y no cambia la configuración de SQL Server. Para guardar resultados locales sin versionarlos, use `reporting-services/validacion/salidas/` (ignorado por Git). No copie ahí contraseñas, exportaciones o registros de pedido.

## Evidencias y pendientes

La publicación y las exportaciones están en 10/10. Cinco vistas agregadas históricas de PDF siguen versionadas en `evidencias/renderizados-2026-11-27/`; las exportaciones completas están en `validacion/salidas/`, ignorado por Git. No se verificó que la identidad Windows del origen compartido tenga el mínimo privilegio `SELECT`, ni se probó el botón P08 en el PBIX; esos controles permanecen abiertos para la integración. El indicador gráfico de R09 requiere ajuste de su responsable. La evidencia completa está en [`validacion/CIERRE_POMA.md`](validacion/CIERRE_POMA.md).

Referencias oficiales: [instalar SSRS](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/install-reporting-services?view=sql-server-ver17), [crear catálogo](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-report-server-create-a-report-server-database?view=sql-server-ver17), [probar credenciales del origen](https://learn.microsoft.com/en-us/sql/reporting-services/report-data/specify-credential-and-connection-information-for-report-data-sources?view=sql-server-ver15), [exportar mediante URL](https://learn.microsoft.com/en-us/sql/reporting-services/export-a-report-using-url-access?view=sql-server-ver17).
