param(
    [Parameter(Mandatory)][string]$Salida,
    [string]$Plantilla = (Join-Path $PSScriptRoot '../ETL_Olist_Ingesta/ETL_Olist_Ingesta.dtproj'),
    [string]$VisualStudio,
    [string]$SqlDts = (Join-Path $env:ProgramFiles 'Microsoft SQL Server/170/DTS'),
    [string]$FalloEn,
    [switch]$ActualizarPublicacion
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if (!$VisualStudio) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $VisualStudio = & $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath
}
if (!$VisualStudio) { throw 'Se requiere Visual Studio 2026 con SSIS Projects.' }
$public = Join-Path $VisualStudio 'Common7/IDE/PublicAssemblies/SSIS/170'
$compiler = Join-Path $env:windir 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$storage = Get-ChildItem (Join-Path $env:windir 'Microsoft.NET/assembly/GAC_MSIL/Microsoft.SqlServer.VSTAScriptingLib') -Filter Microsoft.SqlServer.VSTAScriptingLib.dll -Recurse |
    Where-Object { $_.Directory.Name -match '^v4\.0_17\.0\.0\.0__' } | Select-Object -First 1 -ExpandProperty FullName
$refs = @('ManagedDTS','DTSRuntimeWrap','DTSPipelineWrap','ScriptTask' | ForEach-Object {
    '/r:' + (Join-Path $public "Microsoft.SqlServer.$_.dll")
})
$work = Join-Path $PSScriptRoot ('../obj/generador-' + [guid]::NewGuid().ToString('N'))
$work = (New-Item -ItemType Directory $work).FullName
$script = Join-Path $work 'ST_OrdersSnapshot.dll'
$engine = Join-Path $work 'Generar.exe'

& $compiler /nologo /target:library /optimize+ "/out:$script" @refs '/r:System.Data.dll' (Join-Path $PSScriptRoot 'ScriptMain.cs')
if ($LASTEXITCODE) { throw "Compilación de Script Task: $LASTEXITCODE" }
$sources = @('Generar.cs','Contrato.cs','Publicacion.cs' | ForEach-Object { Join-Path $PSScriptRoot $_ })
$compilerOptions = @('/nologo','/platform:x64','/optimize+',"/out:$engine","/r:$storage",
    ('/r:' + (Join-Path $SqlDts 'Tasks/Microsoft.SqlServer.SQLTask.dll')),
    '/r:System.IO.Compression.dll','/r:System.IO.Compression.FileSystem.dll','/r:System.Xml.Linq.dll','/r:System.Web.Extensions.dll')
& $compiler @compilerOptions @refs @sources
if ($LASTEXITCODE) { throw "Compilación del generador: $LASTEXITCODE" }
Copy-Item -LiteralPath (Join-Path $public 'Microsoft.SqlServer.DTSPipelineWrap.dll'),(Join-Path $public 'Microsoft.SqlServer.ScriptTask.dll') -Destination $work
if (Test-Path -LiteralPath $Salida) {
    throw 'Indica un directorio nuevo para conservar la solución existente.'
}
$dest = New-Item -ItemType Directory $Salida
$configuration = @((Join-Path $repo 'contracts/modelo-dimensional.v1.json'), $PSScriptRoot,
    (Resolve-Path -LiteralPath $Plantilla).Path, $dest.FullName, $script)
if ($FalloEn) { $configuration += $FalloEn }
if ($ActualizarPublicacion) { $configuration += '--actualizar' }
& $engine @configuration
if ($LASTEXITCODE) { throw "Generación y reapertura: $LASTEXITCODE" }
foreach ($extension in 'slnx','database') {
    Copy-Item -LiteralPath (Join-Path (Split-Path $Plantilla) "ETL_Olist_Ingesta.$extension") -Destination $dest.FullName
}
