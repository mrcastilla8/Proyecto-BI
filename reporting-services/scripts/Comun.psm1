Set-StrictMode -Version Latest

function New-OlistSqlConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SqlServerInstance,
        [Parameter(Mandatory = $true)][string]$Database,
        [switch]$TrustServerCertificate
    )

    if ([string]::IsNullOrWhiteSpace($SqlServerInstance)) {
        throw 'Indica -SqlServerInstance; el servidor no se fija en el repositorio.'
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $SqlServerInstance
    $builder['Initial Catalog'] = $Database
    $builder['Integrated Security'] = $true
    $builder['Connect Timeout'] = 8
    $builder['Application Name'] = 'OLIST360-SSRS-M01-M02'
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = [bool]$TrustServerCertificate.IsPresent
    return [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
}

function Invoke-OlistSqlTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SqlServerInstance,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Query,
        [switch]$TrustServerCertificate,
        [ValidateRange(1, 600)][int]$CommandTimeoutSeconds = 30
    )

    $connection = New-OlistSqlConnection -SqlServerInstance $SqlServerInstance -Database $Database -TrustServerCertificate:$TrustServerCertificate
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = $CommandTimeoutSeconds
        $adapter = [System.Data.SqlClient.SqlDataAdapter]::new($command)
        $table = [System.Data.DataTable]::new()
        [void]$adapter.Fill($table)
        return ,$table
    }
    finally {
        if ($null -ne $connection) {
            if ($connection.State -ne [System.Data.ConnectionState]::Closed) { $connection.Close() }
            $connection.Dispose()
        }
    }
}

function Get-OlistInstalledApplications {
    [CmdletBinding()]
    param()

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $uninstallRoots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $null -ne $_.PSObject.Properties['DisplayName'] -and -not [string]::IsNullOrWhiteSpace([string]$_.PSObject.Properties['DisplayName'].Value) } |
            Select-Object DisplayName, DisplayVersion, Publisher
    }
}

function Get-OlistWindowsAdminState {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Export-ModuleMember -Function New-OlistSqlConnection, Invoke-OlistSqlTable, Get-OlistInstalledApplications, Get-OlistWindowsAdminState
