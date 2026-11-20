# Reproducir la ingesta en Windows

Consulta las [versiones observadas](versiones.txt) y la [compilación](compilacion.txt). Ejecuta PowerShell 7 desde la raíz del repositorio con Visual Studio 2026, la extensión SSIS Projects, Integration Services 2025 x64, MSOLEDBSQL y SQLCMD instalados. Los parámetros usan autenticación Windows.

## Regeneración

```powershell
$proyecto = (Resolve-Path 'ssis/ingesta/ETL_Olist_Ingesta').Path
$lab = (Resolve-Path 'ssis/ingesta/obj/issue1-prototipo').Path
$gen = 'ssis/ingesta/generador'
& "$gen/generar.ps1" -Salida "$lab/regenerado"
```

La carpeta de salida debe ser nueva. El script compila el generador y Script Task, genera los paquetes a partir del contrato y comprueba que SSIS puede volver a cargarlos. `-FalloEn Orders` genera una variante de ensayo que inyecta un fallo en la publicación de Orders. Mantén esa variante en una carpeta ignorada.

## Compilar y probar

Para establecer un laboratorio nuevo, crea una instancia LocalDB con nombre exclusivo y la base `BI_OLIST` dentro de un directorio local de ensayos. Aplica en esa instancia los scripts aprobados de `database/` en su orden documentado. Los scripts de pruebas verifican que el servidor sea LocalDB, que la base corresponda al laboratorio y que sus archivos físicos estén en el directorio autorizado. Prepara directorios de evidencias distintos para cada ejecución.

```powershell
$instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
$archivosSql = "$lab/sql"
$csvRoot = Read-Host 'Carpeta autorizada con los nueve CSV'
& "$gen/probar.ps1" -Proyecto $proyecto -Evidencia "$lab/fixtures-nuevas" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -FixturesLf -PorPaquete
& "$gen/probar.ps1" -Proyecto $proyecto -Evidencia "$lab/autenticos-nuevos" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -CsvRoot $csvRoot
& "$gen/probar-recuperacion.ps1" -Proyecto $proyecto -Fixtures "$lab/fixtures-nuevas/fixtures" `
   -ArchivosLocalDb $archivosSql -Instancia $instancia -Evidencia "$lab/recuperacion-nueva"
& "$gen/probar-concurrencia.ps1" -Instancia $instancia -ArchivosLocalDb $archivosSql `
   -Ispac "$lab/autenticos-nuevos/proyecto/bin/Development/ETL_Olist_Ingesta.ispac" `
   -Hashes "$lab/autenticos-nuevos/hashes.csv" -Evidencia "$lab/concurrencia-nueva"
python scripts/validar_base.py
python -m unittest discover -s scripts -p 'test*.py'
```

`probar.ps1` copia el proyecto, configura los tres parámetros de laboratorio, invoca `devenv.com <solución> /Build Development /Out <registro>` y ejecuta el `DTExec.exe` x64 17.x de `%ProgramFiles%\Microsoft SQL Server\170\DTS\Binn` con `/Project <ispac> /Package ETL_Master.dtsx /Reporting EWI`. Usa `-SoloPreparar` para compilar una copia de ensayo y abrir su solución desde Visual Studio. Ejecuta el maestro o inspecciona un paquete desde esa copia.

El maestro valida las entradas y ejecuta Orders, OrderItems, OrderPayments, OrderReviews, Customers, Sellers, Products, Geolocation y CategoryTranslation. Comprueba código de salida 0 en ejecuciones correctas, conciliación de los nueve lotes y conservación de IDs, fechas y conteos en la reejecución. El ensayo con fallo exige código 1, registro `PUBLICAR/51999` y cero filas persistidas del lote fallido. La recuperación exige `COMPLETE` con su mismo ID. La prueba de concurrencia exige `BATCH_LOCK_TIMEOUT` y un lote completo intacto.

`probar.ps1` escribe `conciliar.sql` con cada hash real o sintético. [La consulta de evidencia](../../../generador/sql/consultas-evidencia.sql) reproduce las cuadrículas de esta ejecución concreta y usa los IDs observados en este laboratorio. Para una ejecución nueva usa los IDs de `conciliar-1.log` y `conciliar-2.log`.

## Inspeccionar y mantener la conversión de Reviews

Desde la raíz del repositorio, usa la API del Pipeline con una carpeta ignorada nueva. La sonda termina tras inspeccionar si se proporciona solo el paquete de entrada. Con un segundo argumento guarda una edición de descripción en una salida nueva y comprueba su persistencia, tipos y linajes. Se ejecuta con el runtime SSIS 2025 x64 instalado.

```powershell
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath
$api = Join-Path $vs 'Common7/IDE/PublicAssemblies/SSIS/170'
$csc = Join-Path $env:windir 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$work = (New-Item -ItemType Directory 'ssis/ingesta/obj/diagnostico-reviews').FullName
$source = (Resolve-Path 'ssis/ingesta/generador/diagnostico/RevisarConversion.cs').Path
$package = (Resolve-Path 'ssis/ingesta/ETL_Olist_Ingesta/ETL_OrderReviews.dtsx').Path
$refs = @('ManagedDTS','DTSRuntimeWrap','DTSPipelineWrap' | ForEach-Object {
    '/r:' + (Join-Path $api "Microsoft.SqlServer.$_.dll")
})
& $csc /nologo /platform:x64 "/out:$work\RevisarConversion.exe" @refs $source
if ($LASTEXITCODE) { throw 'Fallo al compilar la sonda.' }
Copy-Item (Join-Path $api 'Microsoft.SqlServer.DTSPipelineWrap.dll') $work
& "$work\RevisarConversion.exe" $package "$work\ETL_OrderReviews.dtsx"
if ($LASTEXITCODE) { throw 'Fallo al comprobar los metadatos.' }
```

Para la regresión, lleva el paquete de salida a una **copia** del proyecto y usa `probar.ps1 -SoloPreparar` con las fixtures y la LocalDB verificadas arriba. Ejecuta `ETL_OrderReviews.dtsx` mediante el `.ispac` de ensayo y compara lote, ordinal, rechazos y la huella Unicode. [Diagnóstico del editor](../anexo-b/DIAGNOSTICO_EDITOR_REVIEWS.md).
