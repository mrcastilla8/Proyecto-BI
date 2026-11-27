[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$SqlServerInstance,
    [ValidateNotNullOrEmpty()][string]$Database = 'BI_OLIST',
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9 _.$@\\-]+$')][string]$ReaderIdentity,
    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Comun.psm1') -Force

try {
    $windowsAccount = [System.Security.Principal.NTAccount]::new($ReaderIdentity)
    [void]$windowsAccount.Translate([System.Security.Principal.SecurityIdentifier])
} catch {
    throw "La identidad Windows '$ReaderIdentity' no se resuelve en este equipo/dominio. Usa una cuenta de servicio ya creada y vuelve a ejecutar."
}

$quotedIdentity = '[' + $ReaderIdentity.Replace(']', ']]') + ']'
$identityLiteral = "N'" + $ReaderIdentity.Replace("'", "''") + "'"
$scriptSql = @"
DECLARE @reader sysname = $identityLiteral;
IF SUSER_ID(@reader) IS NULL
    EXEC (N'CREATE LOGIN ' + QUOTENAME(@reader) + N' FROM WINDOWS');

IF IS_SRVROLEMEMBER(N'sysadmin', @reader) = 1
    THROW 51001, 'La identidad de lectura no puede pertenecer a sysadmin.', 1;
IF EXISTS (
    SELECT 1 FROM sys.server_role_members AS srm
    WHERE srm.member_principal_id = SUSER_ID(@reader)
)
    THROW 51006, 'La identidad ya pertenece a un rol fijo de servidor; revísalo antes de continuar.', 1;

USE [$($Database.Replace(']', ']]'))];
IF OBJECT_ID(N'dw.FactPedidos', N'U') IS NULL OR OBJECT_ID(N'dw.FactDetallePedido', N'U') IS NULL
    THROW 51002, 'Faltan las tablas de hechos requeridas en BI_OLIST.', 1;

DECLARE @user_id int = DATABASE_PRINCIPAL_ID(@reader);
IF @user_id IS NOT NULL AND IS_ROLEMEMBER(N'db_owner', @reader) = 1
    THROW 51003, 'La identidad de lectura no puede pertenecer a db_owner.', 1;
IF @user_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM sys.database_role_members AS drm
    WHERE drm.member_principal_id = @user_id
      AND drm.role_principal_id <> DATABASE_PRINCIPAL_ID(N'public')
)
    THROW 51004, 'La identidad ya pertenece a un rol de base de datos; revísalo antes de conceder acceso.', 1;
IF @user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM sys.database_permissions AS p
    WHERE p.grantee_principal_id = @user_id
      AND p.state IN ('G', 'W')
      AND NOT (p.permission_name = N'SELECT' AND p.class_desc = N'SCHEMA' AND p.major_id = SCHEMA_ID(N'dw'))
      AND p.permission_name <> N'CONNECT'
)
    THROW 51005, 'La identidad ya tiene permisos directos fuera de SELECT en dw; revísalos antes de continuar.', 1;

IF @user_id IS NULL
    EXEC (N'CREATE USER ' + QUOTENAME(@reader) + N' FOR LOGIN ' + QUOTENAME(@reader));
EXEC (N'GRANT SELECT ON SCHEMA::dw TO ' + QUOTENAME(@reader));

DECLARE @checkSql nvarchar(max) = N'EXECUTE AS USER = ' + QUOTENAME(@reader, '''') + N';
IF HAS_PERMS_BY_NAME(N''dw'', N''SCHEMA'', N''SELECT'') <> 1
    THROW 51007, ''La identidad no tiene SELECT efectivo sobre dw.'', 1;
IF HAS_PERMS_BY_NAME(N''dw'', N''SCHEMA'', N''INSERT'') = 1
   OR HAS_PERMS_BY_NAME(N''dw'', N''SCHEMA'', N''UPDATE'') = 1
   OR HAS_PERMS_BY_NAME(N''dw'', N''SCHEMA'', N''DELETE'') = 1
    THROW 51008, ''La identidad tiene permisos DML efectivos sobre dw.'', 1;
REVERT;';
EXEC sys.sp_executesql @checkSql;
SELECT @reader AS reader_identity, N'SELECT en esquema dw; sin DML efectivo' AS resultado;
"@

if ($PSCmdlet.ShouldProcess("$ReaderIdentity en $Database / dw", 'Crear login Windows si falta y conceder solo SELECT de esquema')) {
    $connection = New-OlistSqlConnection -SqlServerInstance $SqlServerInstance -Database 'master' -TrustServerCertificate:$TrustServerCertificate
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $scriptSql
        $command.CommandTimeout = 30
        $reader = $command.ExecuteReader()
        while ($reader.Read()) {
            [pscustomobject]@{ reader_identity = $reader['reader_identity']; resultado = $reader['resultado']; estado = 'CONFIGURED' }
        }
        $reader.Dispose()
    } finally {
        if ($null -ne $connection) {
            if ($connection.State -ne [System.Data.ConnectionState]::Closed) { $connection.Close() }
            $connection.Dispose()
        }
    }
}
