# Resultados M01/M02 — preflight G0

- **Fecha de auditoría local:** 2026-11-26
- **Rama:** `poma/nivel-2-reporting`
- **Base de la rama:** `origin/master` en `eaa652edf022d00d115e7604f86b1d99f905be2d` (actualizada antes del trabajo).
- **Equipo:** Windows 11 Home 25H2, build 26200, x64.
- **Alcance:** M01/M02 del responsable Poma. El preflight `G0` no está superado.

## Resultado observado

| Componente | Resultado real | Consecuencia |
|---|---|---|
| SQL Server | SQL Server 2025 Developer `17.0.1000.7`, servicio del motor activo | Puede alojar el catálogo SSRS y BI_OLIST cuando SSRS se instale. |
| BI_OLIST | ONLINE; `dw.FactPedidos` y `dw.FactDetallePedido` presentes | El humo puede consultar esos hechos mediante conteos agregados. |
| Conteos DW observados | 99.441 pedidos; 112.650 líneas | Referencia informativa de esta auditoría, no un valor a forzar en una carga futura. |
| Power BI Desktop | Store app `2.160.1151.0` detectada | La aplicación está instalada; no prueba que su conexión Live funcione. |
| SSRS | No se detectó aplicación/servicio Reporting Services | M01 bloqueado hasta instalar SSRS 2022 Developer Native Mode. |
| Catálogo SSRS | No existen `ReportServer` ni `ReportServerTempDB` | M01 bloqueado; se deben crear con Configuration Manager. |
| Portal y API SOAP | Sin servicio SSRS ni URLs configuradas | No se pudieron probar HTTP, roles ni publicaciones. |
| Report Builder | No detectado en el inventario de aplicaciones | Instalar desde Microsoft para publicar/probar el RDL. |
| SSAS | Un proceso `msmdsrv.exe` hijo de Visual Studio tiene un listener local dinámico; no hay servicio SSAS instalado | El endpoint guardado antes en la conexión Power BI ya no escucha. PRE-G0-08 pendiente; no se modificó el PBIX. |
| Identidad de lectura | No creada ni habilitada | No se alteraron principals/permisos de SQL. El aprovisionador quedó bajo `-WhatIf` y requiere cuenta dedicada creada. |

La auditoría SQL fue de lectura. La cuenta de consulta local tiene privilegios amplios, por lo que **no se usó ni se configuró como identidad del origen compartido**. No se leyó ni registró ninguna fila con datos de pedidos; solo se consultaron metadatos y conteos agregados.

El instalador oficial de SSRS 2022 se descargó a Temp y su firma se verificó: `Get-AuthenticodeSignature` = `Valid`, firmante Microsoft Corporation; tamaño 137.187.696 bytes, SHA-256 `FA1CBA25C8AEF0A1EE2AB76C809CC5599338740004483C46616C1633BFAD5961`. La versión vigente en la página oficial era `16.0.1121.4` (13/11/2026). **No se ejecutó**: la habilidad `computer-use` exige confirmación justo antes de instalar/ejecutar software recién descargado, aunque la tarea general ya esté autorizada; el siguiente paso requiere esa confirmación y elevación de Windows.

## Archivos preparados

- `datasets/PRE_G0_Humo.sql`: `SELECT` de conteos de hechos y marca UTC.
- `pruebas/humo/PRE_G0_Humo.rdl`: reporte agregado con referencia al origen compartido `/OLIST360/DataSources/BI_OLIST_DW`.
- `scripts/Verificar-Entorno.ps1`: inventario de Windows, SQL, aplicaciones y servicios; la comprobación posterior confirmó un proceso SSAS de espacio de trabajo en Visual Studio.
- `scripts/Verificar-CatalogoSSRS.ps1`: disponibilidad HTTP/Windows auth, WSDL, catálogos y servicio.
- `scripts/Configurar-LectorDW.ps1`: aprovisionamiento explícito de login Windows y concesión mínima de lectura, con `-WhatIf`.
- `scripts/Validar-RDLHumo.ps1`: parseo XML y comparación exacta entre `CommandText` y el SQL versionado.
- `scripts/Exportar-VerificarHumo.ps1`: render URL autenticado y revisión de firmas PDF/XLSX y SHA-256, para ejecutar después de publicar.
- `validacion/matriz.csv`: criterios PRE-G0-01 a PRE-G0-08 con estados reales.

## Comandos y pruebas ejecutados en Windows

```powershell
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test_*.py'
git diff --check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reporting-services\scripts\Validar-Scripts.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reporting-services\scripts\Validar-RDLHumo.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reporting-services\scripts\Verificar-Entorno.ps1 -SqlServerInstance '<instancia local>' -TrustServerCertificate
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reporting-services\scripts\Verificar-CatalogoSSRS.ps1 -SqlServerInstance '<instancia local>' -TrustServerCertificate
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reporting-services\scripts\Configurar-LectorDW.ps1 -SqlServerInstance '<instancia local>' -ReaderIdentity '<cuenta Windows>' -WhatIf
```

Resultados observados:

- `python scripts/validar_base.py`: **PASS** — documentación, contratos, fixtures sintéticas y controles base.
- `python -m unittest discover -s scripts -p 'test_*.py'`: **PASS**, 14 pruebas, 0 fallos.
- `git diff --check`: **PASS** en los cambios rastreados; se repetirá sobre el staging completo antes del commit.
- `Validar-Scripts.ps1`: **PASS** en Windows PowerShell `5.1.26100.9818`, 7 archivos `.ps1/.psm1`, 0 errores de parseo.
- `Validar-RDLHumo.ps1`: **PASS**, RDL-01 a RDL-06 (XML, origen compartido, igualdad exacta `CommandText`/SQL, solo lectura, campos requeridos).
- `Verificar-Entorno.ps1`: SQL `17.0.1000.7`, edición Developer, base ONLINE y hechos presentes **PASS**; Power BI Desktop `2.160.1151.0` **PASS**; SSRS, Report Builder y servicios SSAS/SSRS ausentes **BLOCKED**; sesión sin administrador **BLOCKED**.
- `Verificar-CatalogoSSRS.ps1`: portal y WSDL **BLOCKED** por timeout de conexión; ambas bases `ReportServer`/`ReportServerTempDB` ausentes; servicio SSRS ausente.
- Comprobación posterior de solo lectura: `msmdsrv.exe` es hijo de `devenv.exe`, escucha en un puerto local dinámico y el puerto usado antes en la conexión Power BI no escucha. No se pudo consultar el catálogo XMLA desde PowerShell porque el proveedor OLE DB no está disponible para el proceso de 64 bits. La prueba Live debe hacerse desde Power BI con el endpoint activo, sin guardar cambios al PBIX maestro.
- `Configurar-LectorDW.ps1 -WhatIf`: **PASS** como simulación de `ShouldProcess`; no se abrió conexión SQL ni se ejecutó DDL/DCL.
- El hash SHA-256 de `PRE_G0_Humo.sql` es `40C48B1B5FB98386EE4F197C6788C56E4850EF2FB5A21170DE5C2D5D86A1C495`; el de `PRE_G0_Humo.rdl` es `21E2C921EC0F51517F4BA0A33F4908ABCB949D7F4C8F4665696524A1C86A81F9`.

Las exportaciones, roles del portal, usuario Browser/no autorizado y conexión Live no se simularon; siguen `BLOCKED` mientras no exista el servidor SSRS/SSAS.

## Pendientes para terminar G0

1. Instalar SSRS 2022 Developer en modo nativo y Report Builder con elevación local.
2. Crear `ReportServer`/`ReportServerTempDB` mediante Configuration Manager; configurar URLs locales y servicio.
3. Establecer acceso `System User`/`Browser`, publicador `Content Manager` y demostrar denegación al usuario no autorizado.
4. Crear la identidad Windows dedicada, ejecutar el script de permisos después de revisar `-WhatIf`, y configurar el origen compartido `BI_OLIST_DW` sin doble salto.
5. Publicar/ejecutar PRE-G0-06, exportar/abrir PRE-G0-07 en PDF y EXCELOPENXML, registrar hashes y eliminar la carpeta temporal.
6. Verificar PRE-G0-08 desde Power BI Desktop contra el puerto dinámico de la instancia SSAS de espacio de trabajo activa. La conexión guardada apunta a un puerto que ya no escucha; hay que volver a desplegar/abrir la instancia correcta y refrescar la conexión sin sobrescribir el PBIX maestro de Ángel.

## Limitaciones y archivos preservados

- El entorno actual no permite declarar `PASS` de SSRS ni de SSAS.
- Los cambios preexistentes en `ssas/BI_OLIST_Tabular/BI_OLIST_Tabular.slnx` y `.smproj` se conservaron intactos y no se incluyen en esta rama.
- No hubo cambios en `database/`, `contracts/`, `ssis/`, `ssas/Model.bim` o `powerbi/BI_OLIST.pbix`.
- No se creó, asignó ni vinculó ningún issue, según la instrucción expresa del usuario.
