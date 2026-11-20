[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServidorSql,
    [Parameter(Mandatory)][string]$ServidorTabular,
    [Parameter(Mandatory)][string]$CarpetaTom,
    [ValidatePattern('^BI_OLIST_Tabular(?:_[A-Za-z0-9]+)*$')]
    [string]$BaseTabular = 'BI_OLIST_Tabular',
    [switch]$ConfiarCertificadoSql,
    [switch]$Actualizar
)

$ErrorActionPreference = 'Stop'
foreach ($name in @(
    'Microsoft.AnalysisServices.Core.dll',
    'Microsoft.AnalysisServices.Tabular.Json.dll',
    'Microsoft.AnalysisServices.Tabular.dll'
)) {
    Add-Type -Path (Join-Path $CarpetaTom $name)
}

$definition = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../BI_OLIST_Tabular/Model.bim') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$definition.name = $BaseTabular
$definition | Add-Member -NotePropertyName id -NotePropertyValue $BaseTabular -Force

$source = $definition.model.dataSources[0]
$sqlOptions = [System.Data.Common.DbConnectionStringBuilder]::new()
$sqlOptions.set_ConnectionString($source.connectionString)
$sqlOptions['Data Source'] = $ServidorSql
if ($ConfiarCertificadoSql) { $sqlOptions['Trust Server Certificate'] = 'True' }
$source.connectionString = $sqlOptions.get_ConnectionString()

$target = @{ database = $BaseTabular }
$publication = if ($Actualizar) {
    @{ createOrReplace = @{ object = $target; database = $definition } }
} else {
    @{ create = @{ database = $definition } }
}
$sequence = @{
    sequence = @{
        operations = @(
            $publication,
            @{ refresh = @{ type = 'full'; objects = @($target) } }
        )
    }
}

$tabularOptions = [System.Data.Common.DbConnectionStringBuilder]::new()
$tabularOptions['Data Source'] = $ServidorTabular
$tabularOptions['Integrated Security'] = 'SSPI'
$server = [Microsoft.AnalysisServices.Tabular.Server]::new()
try {
    $server.Connect($tabularOptions.get_ConnectionString())
    $results = $server.Execute(($sequence | ConvertTo-Json -Depth 60 -Compress))
    $failures = @(
        foreach ($result in $results) {
            foreach ($message in $result.Messages) {
                if ($message -is [Microsoft.AnalysisServices.XmlaError]) {
                    "[$($message.ErrorCode)] $($message.Description)"
                } else {
                    Write-Warning $message.Description
                }
            }
        }
    )
    if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    "PASS: $BaseTabular desplegado y procesado en SSAS $($server.Version)."
} finally {
    if ($server.Connected) { $server.Disconnect() }
    $server.Dispose()
}
