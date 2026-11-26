[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SqlServerInstance,
    [ValidateNotNullOrEmpty()][string]$Database = 'BI_OLIST',
    [Parameter(Mandatory = $true)][uri]$PortalUrl,
    [Parameter(Mandatory = $true)][uri]$ReportServerUrl,
    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Comun.psm1') -Force
foreach ($endpoint in @($PortalUrl, $ReportServerUrl)) {
    if (-not $endpoint.IsAbsoluteUri -or $endpoint.Scheme -notin @('http', 'https')) { throw 'Las URLs de SSRS deben ser absolutas y usar HTTP(S).' }
    if (-not $endpoint.IsLoopback) { throw 'Por seguridad, este verificador solo envía credenciales Windows a endpoints de loopback.' }
}

function Get-HttpCheck {
    param([string]$Id, [string]$Criterion, [uri]$Uri)
    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $request.PreAuthenticate = $true
        $request.AllowAutoRedirect = $false
        $request.Timeout = 3000
        if ($Uri.IsLoopback) { $request.Proxy = $null }
        $response = $request.GetResponse()
        try {
            $status = [int]$response.StatusCode
            return [pscustomobject]@{ id = $Id; criterio = $Criterion; estado = $(if ($status -ge 200 -and $status -lt 300) { 'PASS' } else { 'BLOCKED' }); detalle = "HTTP $status; no se siguieron redirecciones." }
        } finally { $response.Dispose() }
    } catch {
        $status = $null
        if ($null -ne $_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch { } }
        $detail = if ($null -ne $status) { "HTTP $status; $($_.Exception.Message)" } else { $_.Exception.Message }
        return [pscustomobject]@{ id = $Id; criterio = $Criterion; estado = 'BLOCKED'; detalle = $detail }
    }
}

$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add((Get-HttpCheck 'PRE-G0-03-PORTAL' 'Portal SSRS con autenticación Windows' $PortalUrl))
$wsdl = [uri]::new($ReportServerUrl.AbsoluteUri.TrimEnd('/') + '/ReportService2010.asmx?wsdl')
$checks.Add((Get-HttpCheck 'PRE-G0-03-SOAP' 'Web Service ReportService2010' $wsdl))

try {
    $catalogQuery = @'
SELECT name, state_desc
FROM sys.databases
WHERE name IN (N'ReportServer', N'ReportServerTempDB')
ORDER BY name;
'@
    $rows = Invoke-OlistSqlTable -SqlServerInstance $SqlServerInstance -Database 'master' -Query $catalogQuery -TrustServerCertificate:$TrustServerCertificate
    $catalogNames = @($rows.Rows | ForEach-Object { $_.name })
    foreach ($required in @('ReportServer', 'ReportServerTempDB')) {
        $row = @($rows.Rows | Where-Object { $_.name -eq $required }) | Select-Object -First 1
        if ($null -eq $row) {
            $checks.Add([pscustomobject]@{ id = "CAT-$required"; criterio = "Catálogo $required"; estado = 'BLOCKED'; detalle = 'No existe en esta instancia SQL.' })
        } elseif ($row.state_desc -eq 'ONLINE') {
            $checks.Add([pscustomobject]@{ id = "CAT-$required"; criterio = "Catálogo $required"; estado = 'PASS'; detalle = 'ONLINE' })
        } else {
            $checks.Add([pscustomobject]@{ id = "CAT-$required"; criterio = "Catálogo $required"; estado = 'BLOCKED'; detalle = "Estado $($row.state_desc)." })
        }
    }
} catch {
    $checks.Add([pscustomobject]@{ id = 'CAT-SQL'; criterio = 'Lectura de catálogo SSRS en SQL'; estado = 'BLOCKED'; detalle = $_.Exception.Message })
}

try {
    $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object {
        $_.Name -match 'ReportServer|SQLServerReportingServices' -or $_.DisplayName -match 'Reporting Services'
    })
    if ($services.Count -eq 0) {
        $checks.Add([pscustomobject]@{ id = 'CAT-SERVICE'; criterio = 'Servicio SSRS Native Mode'; estado = 'BLOCKED'; detalle = 'No hay servicio ReportServer registrado.' })
    } else {
        foreach ($service in $services) {
            $checks.Add([pscustomobject]@{ id = 'CAT-SERVICE'; criterio = 'Servicio SSRS Native Mode'; estado = $(if ($service.State -eq 'Running') { 'PASS' } else { 'BLOCKED' }); detalle = ("{0}: {1}" -f $service.Name, $service.State) })
        }
    }
} catch {
    $checks.Add([pscustomobject]@{ id = 'CAT-SERVICE'; criterio = 'Servicio SSRS Native Mode'; estado = 'BLOCKED'; detalle = $_.Exception.Message })
}

$checks | Format-List id, criterio, estado, detalle
if (@($checks | Where-Object { $_.estado -in @('FAIL', 'BLOCKED') }).Count -gt 0) { exit 2 }
