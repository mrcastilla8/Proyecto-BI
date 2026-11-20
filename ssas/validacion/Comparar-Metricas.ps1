[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServidorSql,
    [Parameter(Mandatory)][string]$ServidorTabular,
    [Parameter(Mandatory)][string]$CarpetaAdomd,
    [string]$BaseTabular = 'BI_OLIST_Tabular',
    [switch]$ConfiarCertificadoSql
)

$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $CarpetaAdomd 'Microsoft.AnalysisServices.AdomdClient.dll')

function Read-Results($Connection, [string]$File) {
    $command = $Connection.CreateCommand()
    $command.CommandText = Get-Content -LiteralPath (Join-Path $PSScriptRoot $File) -Raw -Encoding UTF8
    $command.CommandTimeout = 180
    try {
        $Connection.Open()
        $reader = $command.ExecuteReader()
        try {
            while ($reader.Read()) {
                $row = [ordered]@{}
                for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                    # ADOMD devuelve los alias de ROW entre corchetes.
                    $name = $reader.GetName($index).Trim('[', ']')
                    $row[$name] = if ($reader.IsDBNull($index)) { $null } else { $reader.GetValue($index) }
                }
                [pscustomobject]$row
            }
        } finally {
            $reader.Dispose()
        }
    } finally {
        $command.Dispose()
        $Connection.Dispose()
    }
}

$sqlOptions = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$sqlOptions['Data Source'] = $ServidorSql
$sqlOptions['Initial Catalog'] = 'BI_OLIST'
$sqlOptions['Integrated Security'] = $true
$sqlOptions['Encrypt'] = $true
$sqlOptions['TrustServerCertificate'] = $ConfiarCertificadoSql.IsPresent
$sqlResults = @(Read-Results ([System.Data.SqlClient.SqlConnection]::new($sqlOptions.get_ConnectionString())) 'metricas.sql')

$tabularOptions = [System.Data.Common.DbConnectionStringBuilder]::new()
$tabularOptions['Data Source'] = $ServidorTabular
$tabularOptions['Initial Catalog'] = $BaseTabular
$tabularOptions['Integrated Security'] = 'SSPI'
$daxResults = @(Read-Results ([Microsoft.AnalysisServices.AdomdClient.AdomdConnection]::new(
    $tabularOptions.get_ConnectionString()
)) 'metricas.dax')

if (!$sqlResults.Count -or $sqlResults.Count -ne $daxResults.Count) {
    throw 'SQL y DAX devolvieron diferentes cantidades de escenarios.'
}

$daxByScenario = @{}
foreach ($row in $daxResults) {
    if ($daxByScenario.ContainsKey($row.escenario)) { throw "Escenario DAX duplicado: $($row.escenario)" }
    $daxByScenario[$row.escenario] = $row
}

$matches = 0
$checkedScenarios = @{}
foreach ($sqlRow in $sqlResults) {
    $scenario = $sqlRow.escenario
    $daxRow = $daxByScenario[$scenario]
    if (!$daxRow -or $checkedScenarios.ContainsKey($scenario)) { throw "Escenario inesperado: $scenario" }
    $checkedScenarios[$scenario] = $true

    foreach ($column in $sqlRow.PSObject.Properties.Name | Where-Object { $_ -ne 'escenario' }) {
        if (!$daxRow.PSObject.Properties[$column]) { throw "Falta la métrica DAX $column." }
        $expected = $sqlRow.$column
        $actual = $daxRow.$column
        if ($null -eq $expected -and $null -eq $actual) { continue }

        $tolerance = if ($column -in @(
            'pedidos_totales', 'pedidos_entregados_con_items',
            'ventas_productos_entregados', 'flete_pedidos_entregados'
        )) { [decimal]0 } else { [decimal]0.0000001 }
        if ($null -eq $expected -or $null -eq $actual -or
            [math]::Abs([decimal]$expected - [decimal]$actual) -gt $tolerance) {
            throw "$scenario / ${column}: SQL=$expected; DAX=$actual."
        }
        $matches++
    }
    "PASS $scenario"
}
"PASS $matches valores no vacíos y coincidencia de vacíos"
$daxResults
