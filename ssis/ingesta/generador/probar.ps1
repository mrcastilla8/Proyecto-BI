param(
    [Parameter(Mandatory)][string]$Proyecto,
    [Parameter(Mandatory)][string]$Evidencia,
    [Parameter(Mandatory)][string]$ArchivosLocalDb,
    [string]$CsvRoot,
    [string]$VisualStudio,
    [string]$SqlDts = (Join-Path $env:ProgramFiles 'Microsoft SQL Server/170/DTS'),
    [string]$Instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO',
    [switch]$SoloPreparar,
    [switch]$FixturesLf,
    [switch]$PorPaquete,
    [switch]$FalloEsperado
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$contract = Get-Content (Join-Path $repo 'contracts/modelo-dimensional.v1.json') -Raw | ConvertFrom-Json
if ($Instancia -notmatch '^\(localdb\)\\[a-zA-Z0-9_-]+$') { throw 'La prueba exige una LocalDB con nombre.' }
if (Test-Path -LiteralPath $Evidencia) { throw 'La carpeta de la prueba debe ser nueva.' }
$evidence = (New-Item -ItemType Directory $Evidencia).FullName
$prefix = (Resolve-Path -LiteralPath $ArchivosLocalDb).Path.TrimEnd('\') + '\'
$escaped = $prefix.Replace("'", "''")
$guard = "SET NOCOUNT ON; IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>'BI_OLIST' OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN(N'$escaped'))<>N'$escaped') THROW 51900,'Destino fuera del laboratorio',1;"

function Invoke-Lab([string]$Query, [string]$Target) {
    & sqlcmd -S $Instancia -E -C -l 10 -b -r 1 -W -s '|' -d BI_OLIST -Q "$guard $Query" 2>&1 |
        Tee-Object -FilePath $Target | Out-Host
    if ($LASTEXITCODE) { throw "SQLCMD devolvió $LASTEXITCODE. Ver $Target" }
}
Invoke-Lab "SELECT DB_NAME() AS base,CONVERT(varchar(32),SERVERPROPERTY('ProductVersion')) AS version;" "$evidence/identidad.log"

$enabledFixtures = !$CsvRoot
if ($enabledFixtures) {
    $CsvRoot = (New-Item -ItemType Directory (Join-Path $evidence 'fixtures')).FullName
    foreach ($source in $contract.staging_sources) {
        $fixture = Join-Path $repo ('data/fixtures/' + $source.fixture)
        $rows = @(Import-Csv -LiteralPath $fixture -Encoding utf8)
        if (!$rows.Count) { throw "Fixture vacía: $($source.fixture)" }
        $sample = $rows[0].PSObject.Copy()
        $first = ($source.columns[0] -split ' ')[0]
        if ($source.table -eq 'stg.OrderReviews') {
            $sample.review_comment_title = ''
            $sample.review_comment_message = ('長' * 3770) + [char]34 + ", ñ`r`n" + ('ñ' * 224)
            $rows += $sample
            $sample = $sample.PSObject.Copy()
            $sample.review_score = '6'
        } else {
            $rows += $sample
            $sample = $sample.PSObject.Copy()
            $sample.$first = ''
        }
        $rows += $sample
        $path = Join-Path $CsvRoot $source.file
        $lines = $rows | ConvertTo-Csv -NoTypeInformation -UseQuotes AsNeeded
        $translation = $source.table -eq 'stg.ProductCategoryTranslation'
        $terminator = if ($FixturesLf) { "`n" } else { "`r`n" }
        $body = [string]::Join($terminator,$lines)
        if (!$translation) { $body += $terminator }
        # The source files have unquoted canonical headers. Fields may quote, escape and span lines.
        [IO.File]::WriteAllText($path, $body, [Text.UTF8Encoding]::new($translation))
    }
}
$CsvRoot = (Resolve-Path -LiteralPath $CsvRoot).Path
$files = foreach ($source in $contract.staging_sources) {
    $file = Get-Item -LiteralPath (Join-Path $CsvRoot $source.file)
    [pscustomobject]@{ Source=$source.table.Substring(4); Filename=$source.file;
        SHA256=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant(); Bytes=$file.Length }
}
$files | Export-Csv -NoTypeInformation -LiteralPath "$evidence/hashes.csv"

$copy = (New-Item -ItemType Directory (Join-Path $evidence 'proyecto')).FullName
Get-ChildItem -LiteralPath $Proyecto -File | Where-Object Extension -in '.database','.dtproj','.dtsx','.params','.slnx' |
    Copy-Item -Destination $copy
[xml]$parameters = Get-Content -LiteralPath "$copy/Project.params" -Raw
$values = @{ CSV_ROOT=$CsvRoot; SQL_SERVER=$Instancia; SQL_DATABASE='BI_OLIST' }
foreach ($parameter in $parameters.SelectNodes('//*[local-name()="Parameter"]')) {
    $name = $parameter.Attributes.GetNamedItem('Name','www.microsoft.com/SqlServer/SSIS').Value
    $property = $parameter.SelectSingleNode('.//*[local-name()="Property"][@*[local-name()="Name"]="Value"]')
    $property.InnerText = $values[$name]
}
$parameters.Save("$copy/Project.params")

if (!$VisualStudio) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $VisualStudio = & $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath
}
if (!$VisualStudio) { throw 'Visual Studio 2026 no encontrado.' }
$devenv = Join-Path $VisualStudio 'Common7/IDE/devenv.com'
$dtexec = Join-Path $SqlDts 'Binn/DTExec.exe'
$solution = Join-Path $copy 'ETL_Olist_Ingesta.slnx'
& $devenv $solution /Build Development /Out "$evidence/compilar.log" | Out-Host
if ($LASTEXITCODE) { throw "Compilación de Visual Studio: $LASTEXITCODE" }
$ispac = Join-Path $copy 'bin/Development/ETL_Olist_Ingesta.ispac'
if (!(Test-Path -LiteralPath $ispac)) { throw 'No se generó el .ispac' }
if ($SoloPreparar) { $solution; return }

function Invoke-Package([string]$Package, [int]$Expected, [string]$Log) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    & $dtexec /Project $ispac /Package $Package /Reporting EWI 2>&1 | Set-Content -LiteralPath $Log
    $result = $LASTEXITCODE
    "$Package | DTExec=$result | $([math]::Round($clock.Elapsed.TotalSeconds,2)) s" |
        Tee-Object "$evidence/tiempos.log" -Append
    if ($result -ne $Expected) { throw "DTExec devolvió $result. Ver $Log" }
}

$query = foreach ($file in $files) {
    $name = $file.Source
    $hash = $file.SHA256
    $negativeAssertion = if ($enabledFixtures) {
        "IF NOT EXISTS (SELECT 1 FROM audit.Reject WHERE batch_id=@lot_$name) THROW 51934,'Fixture sin rechazo de $name',1;"
    } else { '' }
    @"
DECLARE @lot_$name bigint;
SELECT @lot_$name=MAX(batch_id) FROM audit.Batch WHERE source_name='$name' AND source_sha256='$hash' AND contract_version='1.0.0';
IF (SELECT COUNT(*) FROM audit.Batch WHERE source_name='$name' AND source_sha256='$hash' AND contract_version='1.0.0')<>1
    THROW 51930,'Identidad de lote no única para $name',1;
IF NOT EXISTS (SELECT 1 FROM audit.Batch WHERE batch_id=@lot_$name AND status='COMPLETE'
    AND rows_read=rows_accepted+rows_rejected
    AND rows_accepted=(SELECT COUNT_BIG(*) FROM stg.[$name] WHERE batch_id=@lot_$name)
    AND rows_rejected=(SELECT COUNT_BIG(*) FROM audit.Reject WHERE batch_id=@lot_$name))
    THROW 51931,'Conciliación inválida para $name',1;
$negativeAssertion
SELECT source_name,batch_id,status,rows_read,rows_accepted,rows_rejected,started_at,finished_at
FROM audit.vw_BatchStatus WHERE batch_id=@lot_$name;
SELECT source_row_number,field_name,reason_code FROM audit.Reject WHERE batch_id=@lot_$name
ORDER BY source_row_number;
"@
}
$query = $query -join "`n"
$query | Set-Content "$evidence/conciliar.sql"
if ($FalloEsperado) {
    Invoke-Package 'ETL_Master.dtsx' 1 "$evidence/fallo.log"
    return
}
if ($PorPaquete) {
    foreach ($file in $files) {
        $name = if ($file.Source -eq 'ProductCategoryTranslation') { 'CategoryTranslation' } else { $file.Source }
        Invoke-Package "ETL_$name.dtsx" 0 "$evidence/ETL_$name.log"
    }
}
Invoke-Package 'ETL_Master.dtsx' 0 "$evidence/maestro-1.log"
Invoke-Lab $query "$evidence/conciliar-1.log"
Invoke-Package 'ETL_Master.dtsx' 0 "$evidence/maestro-2.log"
Invoke-Lab $query "$evidence/conciliar-2.log"
$before = Get-Content "$evidence/conciliar-1.log" -Raw
$after = Get-Content "$evidence/conciliar-2.log" -Raw
if ($before -cne $after) { throw 'La segunda ejecución cambió la auditoría.' }
'PASS: conciliación y reejecución de nueve fuentes' | Set-Content "$evidence/resultado.log"
