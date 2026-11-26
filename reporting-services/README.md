# SSRS 2022 Native Mode — OLIST 360° (M01/M02)

Esta entrega prepara el preflight `G0`: instalación/configuración de SSRS, catálogo nativo, portal, permisos Windows, origen compartido de lectura y reporte temporal de humo con exportación PDF/XLSX. No implementa informes R01–R10, plantillas de M03, ni modifica SSAS, Power BI, SSIS, `database/` o contratos.

## Resultado de esta máquina

El inventario y sus limitaciones están en [`validacion/RESULTADOS_M01_M02.md`](validacion/RESULTADOS_M01_M02.md) y [`validacion/matriz.csv`](validacion/matriz.csv). En la última comprobación, SQL Server Developer y las tablas de hechos `dw.FactPedidos`/`dw.FactDetallePedido` existen; SSRS y su catálogo faltan. Visual Studio tiene activo su motor SSAS de espacio de trabajo con un puerto dinámico, pero el endpoint guardado previamente en Power BI ya no está escuchando. Por eso no se declara superado G0 ni se inventan capturas, publicaciones o exportaciones.

## Requisitos y límites

- Windows de escritorio compatible, permisos de administrador local para instalar/configurar servicios, SQL Server Developer para el catálogo y el DW, y espacio libre suficiente.
- Instalar **SQL Server 2022 Reporting Services (SSRS), edición Developer, modo nativo**, desde Microsoft. La página oficial mostraba `16.0.1121.4` (13/11/2026) al revisar el `26/11/2026`; vuelve a comprobar la versión vigente antes de descargar. No sustituir por Power BI Report Server.
- Report Builder para editar/publicar el RDL. La extensión de Reporting Services para Visual Studio es opcional.
- `BI_OLIST` con el esquema dimensional cargado. Power BI Live a SSAS es una comprobación separada de `G0`; esta entrega no instala/configura el motor SSAS ni cambia el PBIX.
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

1. En la página **Site Settings → Security**, otorgue `System User` a los lectores autorizados. En la raíz `/OLIST360`, asigne el rol integrado `Browser` a los lectores y `Content Manager` solo a la cuenta publicadora/administradora. No convierta a los lectores en autores.
2. Cree `/OLIST360` y estas carpetas exactas: `01_Gerencia`, `02_Comercial`, `03_Operaciones`, `04_Auditoria`, `DataSources`. Para el humo cree temporalmente `/OLIST360/Pruebas`; se eliminará al finalizar la prueba.
3. En `/OLIST360/DataSources`, cree un origen compartido llamado `BI_OLIST_DW`, proveedor SQL Server, base `BI_OLIST`. Ingrese el servidor/instancia local que realmente usa el equipo. No escriba servidor, puerto o credenciales en Git.
4. Seleccione credenciales Windows almacenadas de forma segura en el servidor y marque **Use as Windows credentials when connecting to the data source**. Ingrese una identidad Windows dedicada de lectura, no la cuenta personal administradora. Así se evita depender de la doble delegación Kerberos.
5. Abra PowerShell elevado con acceso administrador a SQL y ejecute `Configurar-LectorDW.ps1` para el usuario Windows que creó previamente. El script crea el login/usuario si falta y concede `SELECT` a `dw`; aborta ante membresías de privilegio elevado o permisos de escritura existentes. Primero use `-WhatIf` y luego revise la cuenta antes de repetir sin él:

   ```powershell
   .\reporting-services\scripts\Configurar-LectorDW.ps1 `
     -SqlServerInstance '<instancia SQL local>' `
     -ReaderIdentity '<EQUIPO\cuenta_lectora>' -WhatIf
   ```

   ```powershell
   .\reporting-services\scripts\Configurar-LectorDW.ps1 `
     -SqlServerInstance '<instancia SQL local>' `
     -ReaderIdentity '<EQUIPO\cuenta_lectora>'
   ```

   Si SQL local usa un certificado de desarrollo no confiable, `-TrustServerCertificate` se permite solo para loopback en este laboratorio. Nunca elevar la identidad a `sysadmin`, `db_owner` o `db_datawriter`.
6. En el portal, pruebe `Test Connection` del origen compartido y guarde. No habilite `Prompt` o `Windows Integrated Security` con credenciales del usuario interactivo como sustituto de la identidad dedicada.
7. Pruebe una cuenta autorizada con Browser y una cuenta Windows no autorizada; registre acceso de lectura y rechazo. Compruebe que Browser no puede cargar/publicar archivos. No use cuentas de terceros ni cambie sus permisos.

## Prueba temporal de humo PRE-G0-06/07

1. Antes de publicar, ejecute la validación estática:

   ```powershell
   .\reporting-services\scripts\Validar-RDLHumo.ps1
   ```

   El `CommandText` debe coincidir exactamente con [`datasets/PRE_G0_Humo.sql`](datasets/PRE_G0_Humo.sql), usar `BI_OLIST_DW` y consultar solo conteos agregados.
2. En Report Builder, abra [`pruebas/humo/PRE_G0_Humo.rdl`](pruebas/humo/PRE_G0_Humo.rdl), compruebe la referencia de origen `/OLIST360/DataSources/BI_OLIST_DW` y guárdelo en `/OLIST360/Pruebas/PRE_G0_Humo`.
3. Ejecute `Verificar-CatalogoSSRS.ps1` con las URLs efectivas y confirme servicios/catálogos/HTTP. Ejecute la prueba desde el portal. Los conteos esperados de la evidencia actual son 99.441 pedidos y 112.650 líneas; si la base cambió, documente el valor observado, no fuerce la carga.
4. Exporte desde el portal a PDF y Excel (`EXCELOPENXML`). Opcionalmente, use `Exportar-VerificarHumo.ps1` con la URL de Web Service y una carpeta temporal fuera del repositorio. Comprueba HTTP, firma PDF/ZIP XLSX y SHA-256; no conserva ni sube los archivos.
5. Registre resultado, URL real, fecha, HEAD y hash local en `validacion/matriz.csv`/`evidencias/INDICE.md`. Redacte capturas para que no muestren identidad Windows, credenciales ni datos de pedidos.
6. Elimine `/OLIST360/Pruebas` desde el portal al terminar y verifique que no quedan elementos de humo. No borre los orígenes compartidos ni el catálogo.

## Comandos de preflight

Ejecutar desde la raíz del repositorio en Windows PowerShell 5.1 o posterior. Los scripts de inventario y validación no hacen cambios; `Configurar-LectorDW.ps1` sí modifica únicamente permisos/principales SQL y requiere revisar el `-WhatIf` primero.

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

El estado ejecutado está en [`validacion/RESULTADOS_M01_M02.md`](validacion/RESULTADOS_M01_M02.md); el índice normativo es [`evidencias/INDICE.md`](evidencias/INDICE.md). Para declarar G0 completo aún se necesitan SSRS instalado, catálogo ONLINE, portal, roles probados, identidad de lectura, reporte ejecutado, exportaciones reales PDF/XLSX y conexión Live a SSAS comprobada desde Power BI Desktop.

Referencias oficiales: [instalar SSRS](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/install-reporting-services?view=sql-server-ver17), [crear catálogo](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-report-server-create-a-report-server-database?view=sql-server-ver17), [probar credenciales del origen](https://learn.microsoft.com/en-us/sql/reporting-services/report-data/specify-credential-and-connection-information-for-report-data-sources?view=sql-server-ver15), [exportar mediante URL](https://learn.microsoft.com/en-us/sql/reporting-services/export-a-report-using-url-access?view=sql-server-ver17).
