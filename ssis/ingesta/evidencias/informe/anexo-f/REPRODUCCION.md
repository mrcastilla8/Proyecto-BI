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

## Reproducir la corrección de integridad de texto

Desde la raíz del repositorio, conserva los lotes previos en la LocalDB. La base de validación admite una primera carga del mismo hash. El inicializador exige una instancia LocalDB con nombre y un directorio nuevo. Aplica los scripts 00, 01 y 02 ajustando el catálogo en copias privadas, más los bloques de índices de staging y vista de auditoría del 05. Verifica nueve tablas staging, dos de auditoría, la vista y cero lotes iniciales. Si la base de validación ya existe, termina sin cambiarla.

```powershell
$instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
$base = 'BI_OLIST_VALIDACION_TEXTO'
$lab = (Resolve-Path 'ssis/ingesta/obj').Path
$carpeta = "$lab/texto-nuevo"
$gen = 'ssis/ingesta/generador'
$proyecto = (Resolve-Path 'ssis/ingesta/ETL_Olist_Ingesta').Path
$csvRoot = Read-Host 'Carpeta local autorizada con los nueve CSV'

& "$gen/preparar-laboratorio-texto.ps1" -Instancia $instancia -Evidencia $carpeta
# Opcional si se están comprobando cambios del generador sobre los paquetes existentes.
& "$gen/generar.ps1" -Salida "$carpeta/actualizado" -ActualizarPublicacion
$common = @{
    Proyecto = $proyecto
    ArchivosLocalDb = "$carpeta/sql"
    Instancia = $instancia
    Base = $base
}
& "$gen/probar.ps1" @common -CsvRoot $csvRoot -Evidencia "$carpeta/autenticos"
& "$gen/probar.ps1" @common -Evidencia "$carpeta/fixtures" -PorPaquete -FixturesLf
& "$gen/probar-recuperacion.ps1" @common -Fixtures "$carpeta/fixtures/fixtures" `
    -Evidencia "$carpeta/recuperacion"

$perfil = 'ssis/ingesta/evidencias/informe/anexo-b/perfil-autentico.json'
python "$gen/verificar_valores.py" --csv $csvRoot --perfil $perfil --archivos "$carpeta/sql" `
    --instancia $instancia --base $base
& "$gen/verificar-integridad.ps1" -Perfil $perfil -HashesFixtures "$carpeta/fixtures/hashes.csv" `
    -ArchivosLocalDb "$carpeta/sql" -Instancia $instancia -Base $base -Consulta "$carpeta/integridad.sql"
```

`-ActualizarPublicacion` usa ManagedDTS para editar en una copia las tareas de SQL y de conexión, sin recrear los flujos de datos. Si se usa esa salida para probar un cambio, establece `$common.Proyecto` a la ruta generada. Las pruebas toman el catálogo de `-Base` y verifican su identidad y los archivos físicos antes de ejecutar.

La comparación global recorre cada ordinal del CSV y la tabla de destino. Distingue NULL de una cadena no vacía y compara longitud y SHA-256 de la representación UTF-16LE de las columnas. Los enteros y decimales se representan con su tipo y escala del contrato. La salida contiene totales y, ante diferencias, una muestra de ordinales sin datos de fila. La [consulta antes y después](../../../generador/sql/conciliar-texto-reviews.sql) compara el lote auténtico histórico y el nuevo dentro de la misma instancia LocalDB. [Resultados reproducidos](../anexo-b/texto-integridad.txt).

## Ejecutar en BI_OLIST principal

Para una carga inicial, identifica primero el servicio de SQL Server instalado y verifica en lectura `@@SERVERNAME`, `DB_NAME()` e identidad efectiva. Confirma esquema, permisos del ejecutor, los nueve hashes de los CSV, espacio, ausencia de actividad interferente y que staging y auditoría estén vacíos. En esta entrega la instancia principal era el servicio predeterminado local `MSSQLSERVER`. [Preflight observado](../anexo-b/principal-preflight.txt).

Copia la solución a un directorio local ignorado. Configura `SQL_SERVER` con el destino verificado, `SQL_DATABASE=BI_OLIST` y `CSV_ROOT` con la carpeta local. Compila esa copia con `devenv.com <solución> /Build Development /Out <registro>`. Ejecuta `DTExec.exe /Project <ispac> /Package ETL_Master.dtsx /Reporting EWI` usando el runtime x64 17.x y guarda la salida y el código de retorno.

Antes de repetir, concilia los lotes y compara los CSV mediante `python ssis/ingesta/generador/verificar_valores.py --principal --csv <carpeta> --perfil <perfil-autentico.json>`. Esta opción abre en solo lectura la base `BI_OLIST` de la instancia predeterminada del mismo equipo a través de memoria compartida y verifica su identidad. Ejecuta la [consulta de disponibilidad](../../../generador/sql/consultas-principal.sql) para los lotes de esta carga. Tras la reejecución, compara IDs, estados, fechas y conteos. Los resultados de esta instancia son independientes de LocalDB. [Cargas verificadas](../anexo-b/principal-carga.txt) y [huella de reejecución](../anexo-b/principal-idempotencia.txt).

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
