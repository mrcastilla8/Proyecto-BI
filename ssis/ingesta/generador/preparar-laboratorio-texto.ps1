param(
    [Parameter(Mandatory)][string]$Evidencia,
    [string]$Instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
)
$ErrorActionPreference = 'Stop'
if ($Instancia -notmatch '^\(localdb\)\\[a-zA-Z0-9_-]+$') { throw 'Se requiere LocalDB con nombre.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = (New-Item -ItemType Directory $Evidencia).FullName
$physical = (New-Item -ItemType Directory "$output/sql").FullName
$base = 'BI_OLIST_VALIDACION_TEXTO'
$guard = "SET NOCOUNT ON; IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 THROW 51900,'Destino fuera de LocalDB',1;"
$mdf = (Join-Path $physical "$base.mdf").Replace("'","''")
$ldf = (Join-Path $physical "${base}_log.ldf").Replace("'","''")
$create = "IF DB_ID(N'$base') IS NOT NULL THROW 51902,'Base de validación ya existe',1; CREATE DATABASE [$base] ON PRIMARY (NAME=N'$base', FILENAME=N'$mdf') LOG ON (NAME=N'${base}_log', FILENAME=N'$ldf');"
& sqlcmd -S $Instancia -d master -E -C -b -Q "$guard $create"
if ($LASTEXITCODE) { throw 'No se creó la base nueva.' }

$prefix = $physical.TrimEnd('\').Replace("'","''") + '\'
$guard += " IF DB_NAME()<>N'$base' OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN(N'$prefix'))<>N'$prefix') THROW 51901,'Base fuera del laboratorio',1;"
function Apply-Ddl([string]$name,[string]$ddl) {
    $target = Join-Path $output $name
    @($guard,'GO',$ddl) | Set-Content -LiteralPath $target -Encoding utf8
    & sqlcmd -S $Instancia -d $base -E -C -b -i $target
    if ($LASTEXITCODE) { throw "No se aplicó $name." }
}
foreach ($name in '00_crear_base.sql','01_auditoria.sql','02_staging.sql') {
    $ddl = Get-Content -LiteralPath (Join-Path $repo "database/$name") -Raw
    Apply-Ddl $name ($ddl.Replace('BI_OLIST',$base))
}
$controls = (Get-Content -LiteralPath (Join-Path $repo 'database/05_controles.sql') -Raw) -split '(?im)^GO\s*$'
$staging = @($controls | Where-Object { $_ -match 'DECLARE @staging_name SYSNAME|CREATE OR ALTER VIEW audit\.vw_BatchStatus' })
if ($staging.Count -ne 2) { throw 'No se reconocieron los bloques de ingesta del DDL 05.' }
Apply-Ddl '05_ingesta.sql' ($staging -join "`r`nGO`r`n")
$verify = @"
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'stg'))<>9
    OR (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'audit'))<>2
    OR OBJECT_ID(N'audit.vw_BatchStatus',N'V') IS NULL
    OR EXISTS(SELECT 1 FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dw'))
    OR EXISTS(SELECT 1 FROM audit.Batch)
    THROW 51903,'Esquema o estado inicial inesperado',1;
SELECT DB_NAME() base,CONVERT(varchar(32),SERVERPROPERTY('ProductVersion')) version,
    (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'stg')) tablas_staging,
    (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'audit')) tablas_auditoria,
    (SELECT COUNT_BIG(*) FROM audit.Batch) lotes_iniciales;
"@
& sqlcmd -S $Instancia -d $base -E -C -b -W -s '|' -Q "$guard $verify"
exit $LASTEXITCODE
