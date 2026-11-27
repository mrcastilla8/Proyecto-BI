[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlServerInstance,

    [ValidateNotNullOrEmpty()]
    [string]$Database = 'BI_OLIST',

    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Comun.psm1') -Force

function Add-Check {
    param(
        [string]$Id,
        [string]$Criterio,
        [ValidateSet('PASS', 'FAIL', 'BLOCKED', 'NOT_RUN')][string]$Estado,
        [string]$Detalle
    )
    [pscustomobject]@{ id = $Id; criterio = $Criterio; estado = $Estado; detalle = $Detalle }
}

$checks = [System.Collections.Generic.List[object]]::new()
$osError = $null
try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch { $os = $null; $osError = $_.Exception.Message }
if ($null -ne $os) {
    $checks.Add((Add-Check 'WIN-01' 'Windows detectado' 'PASS' ("{0}; build {1}; {2}" -f $os.Caption, $os.BuildNumber, $os.OSArchitecture)))
} else {
    $checks.Add((Add-Check 'WIN-01' 'Windows detectado' 'BLOCKED' $(if ($osError) { $osError } else { 'No se pudo leer Win32_OperatingSystem.' })))
}

$isAdmin = Get-OlistWindowsAdminState
$checks.Add((Add-Check 'WIN-02' 'Sesión elevada para configurar servicios' $(if ($isAdmin) { 'PASS' } else { 'BLOCKED' }) $(if ($isAdmin) { 'PowerShell está elevado.' } else { 'La sesión no está elevada; el asistente de instalación/configuración pedirá elevación.' })))

$apps = @(Get-OlistInstalledApplications)
$appChecks = @(
    @{ Id = 'SSRS-APP'; Criterio = 'SQL Server Reporting Services 2022'; Match = 'Reporting Services' },
    @{ Id = 'RB-APP'; Criterio = 'Microsoft Report Builder'; Match = 'Report Builder' },
    @{ Id = 'SSAS-VS'; Criterio = 'Extensión Analysis Services Projects'; Match = 'Analysis Services Projects' },
    @{ Id = 'SSRS-VS'; Criterio = 'Extensión Reporting Services Projects'; Match = 'Reporting Services Projects' }
)
foreach ($item in $appChecks) {
    $found = @($apps | Where-Object { $_.DisplayName -like "*$($item.Match)*" })
    if ($found.Count -gt 0) {
        $versions = ($found | ForEach-Object { if ($_.DisplayVersion) { $_.DisplayVersion } else { 'versión no registrada' } } | Select-Object -Unique) -join ', '
        $checks.Add((Add-Check $item.Id $item.Criterio 'PASS' $versions))
    } else {
        $state = if ($item.Id -in @('SSAS-VS', 'SSRS-VS')) { 'NOT_RUN' } else { 'BLOCKED' }
        $checks.Add((Add-Check $item.Id $item.Criterio $state 'No aparece en las claves estándar de desinstalación; las extensiones VSIX se confirman desde Visual Studio.'))
    }
}

try {
    $powerBi = @(Get-AppxPackage -Name 'Microsoft.MicrosoftPowerBIDesktop' -ErrorAction Stop)
    if ($powerBi.Count -gt 0) {
        $checks.Add((Add-Check 'PBI-APP' 'Power BI Desktop' 'PASS' (($powerBi | ForEach-Object { $_.Version.ToString() } | Select-Object -Unique) -join ', ')))
    } else {
        $powerBiReg = @($apps | Where-Object { $_.DisplayName -match 'Power BI Desktop' })
        if ($powerBiReg.Count -gt 0) { $checks.Add((Add-Check 'PBI-APP' 'Power BI Desktop' 'PASS' (($powerBiReg | ForEach-Object { $_.DisplayVersion } | Select-Object -Unique) -join ', '))) }
        else { $checks.Add((Add-Check 'PBI-APP' 'Power BI Desktop' 'BLOCKED' 'No se encontró la aplicación Store ni la entrada de escritorio.')) }
    }
} catch {
    $checks.Add((Add-Check 'PBI-APP' 'Power BI Desktop' 'NOT_RUN' $_.Exception.Message))
}

try {
    $sql = @'
SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS product_version,
       CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS edition,
       d.state_desc AS database_state,
       CAST(CASE WHEN OBJECT_ID(N'dw.FactPedidos', N'U') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS fact_pedidos,
       CAST(CASE WHEN OBJECT_ID(N'dw.FactDetallePedido', N'U') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS fact_detalle_pedido
FROM sys.databases AS d
WHERE d.name = DB_NAME();
'@
    $row = (Invoke-OlistSqlTable -SqlServerInstance $SqlServerInstance -Database $Database -Query $sql -TrustServerCertificate:$TrustServerCertificate).Rows[0]
    if ($null -eq $row) { throw "La base '$Database' no existe en el servidor indicado." }
    $checks.Add((Add-Check 'SQL-01' 'Motor SQL y base BI_OLIST' 'PASS' ("SQL {0}; {1}; base {2}" -f $row.product_version, $row.edition, $row.database_state)))
    if ([string]$row.database_state -ne 'ONLINE') { $checks.Add((Add-Check 'DW-01' 'Tablas dimensionales para el humo' 'BLOCKED' "La base está en estado $($row.database_state).")) }
    elseif ([bool]$row.fact_pedidos -and [bool]$row.fact_detalle_pedido) { $checks.Add((Add-Check 'DW-01' 'Tablas de hechos para el humo' 'PASS' 'Existen FactPedidos y FactDetallePedido.')) }
    else { $checks.Add((Add-Check 'DW-01' 'Tablas de hechos para el humo' 'BLOCKED' 'Falta una o ambas tablas de hechos requeridas.')) }
} catch {
    $checks.Add((Add-Check 'SQL-01' 'Motor SQL y base BI_OLIST' 'BLOCKED' $_.Exception.Message))
    $checks.Add((Add-Check 'DW-01' 'Tablas de hechos para el humo' 'BLOCKED' 'La comprobación SQL no pudo ejecutarse.'))
}

try {
    $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object {
        $_.Name -match 'ReportServer|MSOLAP' -or $_.DisplayName -match 'Reporting Services|Analysis Services'
    })
    foreach ($serviceName in @('ReportServer', 'MSOLAP')) {
        $service = if ($serviceName -eq 'ReportServer') {
            @($services | Where-Object { $_.Name -match 'ReportServer|SQLServerReportingServices' -or $_.DisplayName -match 'Reporting Services' }) | Select-Object -First 1
        } else {
            @($services | Where-Object { $_.Name -like "$serviceName*" -or $_.DisplayName -match 'Analysis Services' }) | Select-Object -First 1
        }
        if ($null -ne $service) {
            $checks.Add((Add-Check ("SVC-{0}" -f $serviceName) $service.DisplayName $(if ($service.State -eq 'Running') { 'PASS' } else { 'BLOCKED' }) ("Servicio {0}; inicio {1}." -f $service.State, $service.StartMode)))
        } else {
            $checks.Add((Add-Check ("SVC-{0}" -f $serviceName) $(if ($serviceName -eq 'ReportServer') { 'Servicio SSRS' } else { 'Servicio SSAS' }) 'BLOCKED' 'No se encontró un servicio registrado.'))
        }
    }
} catch {
    $checks.Add((Add-Check 'SVC-READ' 'Inventario de servicios SSRS/SSAS' 'BLOCKED' $_.Exception.Message))
}

$checks | Format-List id, criterio, estado, detalle
if (@($checks | Where-Object { $_.estado -in @('FAIL', 'BLOCKED') }).Count -gt 0) { exit 2 }
