# SSRS 2022 Native Mode — OLIST 360° (M01–M05)

Esta entrega instala y configura SSRS 2022 Developer Native Mode, el catálogo local, el portal y un origen compartido a `BI_OLIST`; ejecuta el humo con exportaciones reales; y entrega la plantilla RDL, R07 y R08. Usa autenticación Windows local para esta máquina. No configura SSAS ni modifica Power BI, SSIS, `database/`, contratos o `Model.bim`.

## Resultado de esta máquina

Los resultados observados y evidencias reales se registran en [`validacion/RESULTADOS_M01_M02.md`](validacion/RESULTADOS_M01_M02.md), [`validacion/matriz.csv`](validacion/matriz.csv) y [`evidencias/INDICE.md`](evidencias/INDICE.md). Ningún caso se marca `PASS` sin ejecución local.

## Requisitos y límites

- Windows de escritorio compatible, permisos de administrador local para instalar/configurar servicios, SQL Server Developer para el catálogo y el DW, y espacio libre suficiente.
- **SQL Server 2022 Reporting Services (SSRS), edición Developer, modo nativo**. En este equipo WMI confirma `16.0.1122.6` y el servicio está activo; el catálogo y las URLs locales siguen pendientes. No sustituir por Power BI Report Server.
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
3. Ejecute `Verificar-CatalogoSSRS.ps1` con las URLs efectivas y confirme servicios/catálogos/HTTP. Ejecute la prueba desde el portal. Los conteos esperados de la evidencia actual son 99.441 pedidos y 112.650 líneas; si la base cambió, documente el valor observado, no fuerce la carga.
4. Exporte desde el portal a PDF y Excel (`EXCELOPENXML`). Opcionalmente, use `Exportar-VerificarHumo.ps1` con la URL de Web Service y una carpeta temporal fuera del repositorio. Comprueba HTTP, firma PDF/ZIP XLSX y SHA-256; no conserva ni sube los archivos.
5. Registre resultado, URL real, fecha, HEAD y hash local en `validacion/matriz.csv`/`evidencias/INDICE.md`. Redacte capturas para que no muestren identidad Windows, credenciales ni datos de pedidos.
6. Retire el informe temporal del portal al cerrar la prueba. Conserva el origen compartido y el catálogo.

## M03–M05 — plantilla, R07 y R08

- `diseno/Plantilla_OLIST360.rdl`: base visual reutilizable OLIST 360°, A4 horizontal, cabecera, filtros, tarjetas KPI y área de detalle.
- `reports/R07_ImportesPagados.rdl`: parámetros `Desde`, `Hasta` y `EstadoPedido`; importes y conteos por mes/estado/total, sin convertir `NULL` a cero ni presentar el resultado como ingreso neto.
- `reports/R08_FichaPedido.rdl`: `OrderId` obligatorio; cabecera y detalle separados, nulos visibles, estados para pedido inexistente/sin ítems y montos de línea separados del pago agregado.
- Las consultas SQL en `datasets/` siguen `docs/nivel-2/06_CONTRATO_CONSULTAS_SQL.md`. Publica los diez RDL cuando estén disponibles los ocho informes restantes.

## Comandos de preflight

Ejecutar desde la raíz del repositorio en Windows PowerShell 5.1 o posterior. Los validadores no hacen cambios en SQL.

```powershell
.\reporting-services\scripts\Verificar-Entorno.ps1 -SqlServerInstance '<instancia SQL local>'
.\reporting-services\scripts\Verificar-CatalogoSSRS.ps1 `
  -SqlServerInstance '<instancia SQL local>' `
  -PortalUrl '<URL de loopback del portal>' `
  -ReportServerUrl '<URL de loopback del servicio>'
.\reporting-services\scripts\Validar-RDLHumo.ps1
```

Los scripts devuelven filas `PASS`, `FAIL` o `BLOCKED`; los checks no ejecutados permanecen `NOT_RUN`. Para guardar resultados locales sin versionarlos, use `reporting-services/validacion/salidas/` (ignorado por Git). No copie ahí contraseñas, exportaciones o registros de pedido.

## Evidencias y pendientes

El estado ejecutado está en [`validacion/RESULTADOS_M01_M02.md`](validacion/RESULTADOS_M01_M02.md); el índice de evidencias es [`evidencias/INDICE.md`](evidencias/INDICE.md). Se registran solo instalaciones, consultas, exportaciones y capturas observadas en esta máquina. La integración conjunta de los diez informes queda pendiente hasta recibir los ocho RDL restantes.

Referencias oficiales: [instalar SSRS](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/install-reporting-services?view=sql-server-ver17), [crear catálogo](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-report-server-create-a-report-server-database?view=sql-server-ver17), [probar credenciales del origen](https://learn.microsoft.com/en-us/sql/reporting-services/report-data/specify-credential-and-connection-information-for-report-data-sources?view=sql-server-ver15), [exportar mediante URL](https://learn.microsoft.com/en-us/sql/reporting-services/export-a-report-using-url-access?view=sql-server-ver17).
