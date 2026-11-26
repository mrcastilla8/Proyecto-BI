[CmdletBinding()]
param(
    [string]$ReportPath,
    [string]$SqlPath
)

$ErrorActionPreference = 'Stop'
$componentRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $componentRoot 'pruebas\humo\PRE_G0_Humo.rdl' }
if ([string]::IsNullOrWhiteSpace($SqlPath)) { $SqlPath = Join-Path $componentRoot 'datasets\PRE_G0_Humo.sql' }
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Id, [string]$Criterio, [bool]$Passed, [string]$Detalle)
    $checks.Add([pscustomobject]@{ id = $Id; criterio = $Criterio; estado = $(if ($Passed) { 'PASS' } else { 'FAIL' }); detalle = $Detalle })
}

foreach ($path in @($ReportPath, $SqlPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No existe el archivo requerido: $path" }
}

$sql = (Get-Content -LiteralPath $SqlPath -Raw).Trim()
$xml = [System.Xml.XmlDocument]::new()
$xml.XmlResolver = $null
$xml.Load((Resolve-Path -LiteralPath $ReportPath).Path)
$ns = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
$ns.AddNamespace('r', 'http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition')

$dataSource = $xml.SelectSingleNode('/r:Report/r:DataSources/r:DataSource', $ns)
$reference = if ($null -ne $dataSource) { $dataSource.SelectSingleNode('r:DataSourceReference', $ns) } else { $null }
$command = $xml.SelectSingleNode('/r:Report/r:DataSets/r:DataSet/r:Query/r:CommandText', $ns)
$datasets = $xml.SelectNodes('/r:Report/r:DataSets/r:DataSet', $ns)
$fields = $xml.SelectNodes('/r:Report/r:DataSets/r:DataSet/r:Fields/r:Field', $ns)

Add-Check 'RDL-01' 'RDL 2010 parseable y un dataset' ($datasets.Count -eq 1) ("datasets=$($datasets.Count)")
Add-Check 'RDL-02' 'Origen compartido OLIST 360' ($null -ne $reference -and $reference.InnerText -eq '/OLIST360/DataSources/BI_OLIST_DW') $(if ($null -ne $reference) { $reference.InnerText } else { 'DataSourceReference ausente' })
Add-Check 'RDL-03' 'CommandText idéntico al SQL versionado' ($null -ne $command -and $command.InnerText.Trim() -ceq $sql) 'Comparación textual exacta luego de quitar espacios exteriores.'
Add-Check 'RDL-04' 'Consulta comienza con SELECT y no usa stg' ($sql -match '^SELECT\b' -and $sql -notmatch '(?i)\bstg\s*\.') 'Solo lectura de conteos agregados.'
$forbidden = '(?i)\b(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|EXEC(?:UTE)?)\b|error_message|source_file|execution_context'
Add-Check 'RDL-05' 'Sin mutaciones ni columnas restringidas' ($sql -notmatch $forbidden) 'Revisión estática de términos prohibidos.'
$requiredFields = @('pedidos', 'lineas', 'fecha_ejecucion_utc')
$actualFields = @($fields | ForEach-Object { $_.GetAttribute('Name') })
Add-Check 'RDL-06' 'Campos requeridos para el humo' (@($requiredFields | Where-Object { $_ -notin $actualFields }).Count -eq 0) ($actualFields -join ', ')

$checks
if (@($checks | Where-Object { $_.estado -ne 'PASS' }).Count -gt 0) { exit 1 }
