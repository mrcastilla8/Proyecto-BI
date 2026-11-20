param(
    [Parameter(Mandatory)][string]$Ispac,
    [Parameter(Mandatory)][string]$Hashes,
    [Parameter(Mandatory)][string]$ArchivosLocalDb,
    [Parameter(Mandatory)][string]$Evidencia,
    [ValidateSet('BI_OLIST','BI_OLIST_VALIDACION_TEXTO')][string]$Base = 'BI_OLIST',
    [string]$Instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO',
    [string]$Dtexec = (Join-Path $env:ProgramFiles 'Microsoft SQL Server/170/DTS/Binn/DTExec.exe')
)
$ErrorActionPreference = 'Stop'
if ($Instancia -notmatch '^\(localdb\)\\[a-zA-Z0-9_-]+$') { throw 'La prueba exige LocalDB.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Ispac).Path)
try {
    $reader = [IO.StreamReader]::new($archive.GetEntry('Project.params').Open())
    try { [xml]$parameters = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $ns = [Xml.XmlNamespaceManager]::new($parameters.NameTable)
    $ns.AddNamespace('s', 'www.microsoft.com/SqlServer/SSIS')
    $server = $parameters.SelectSingleNode("//s:Parameter[@s:Name='SQL_SERVER']//s:Property[@s:Name='Value']", $ns).InnerText
    $database = $parameters.SelectSingleNode("//s:Parameter[@s:Name='SQL_DATABASE']//s:Property[@s:Name='Value']", $ns).InnerText
    if ($server -cne $Instancia -or $database -cne $Base) { throw 'El ISPAC debe apuntar al laboratorio verificado.' }
} finally { $archive.Dispose() }
$out = (New-Item -ItemType Directory $Evidencia).FullName
$path = (Resolve-Path -LiteralPath $ArchivosLocalDb).Path.TrimEnd('\').Replace("'","''") + '\'
$guard = "SET NOCOUNT ON; IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>N'$Base' OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN(N'$path'))<>N'$path') THROW 51900,'Destino fuera del laboratorio',1;"
$hash = (Import-Csv -LiteralPath $Hashes | Where-Object Source -eq Orders).SHA256
if ($hash -notmatch '^[0-9a-f]{64}$') { throw 'Hash de Orders inválido.' }
$resource = "BIOLIST:ingesta:Orders:$($hash):1.0.0"
$query = "SELECT CONCAT(batch_id,'|',status,'|',started_at,'|',finished_at,'|',rows_read,'|',rows_accepted,'|',rows_rejected) FROM audit.Batch WHERE source_name='Orders' AND source_sha256='$hash';"
function Query([string]$sql) {
    $rows = & sqlcmd -S $Instancia -E -C -l 5 -b -d $Base -h -1 -W -Q "$guard $sql"
    if ($LASTEXITCODE) { throw 'Error en la consulta de bloqueo' }
    $rows
}
$before = Query $query
if ($before -notmatch '\|COMPLETE\|') { throw 'Falta el lote completo de prueba.' }
$block = "$guard DECLARE @rc int; EXEC @rc=sys.sp_getapplock @Resource=N'$resource',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @rc<0 THROW 51921,'Bloqueo no adquirido',1; WAITFOR DELAY '00:00:14';"
$job = Start-Job -ArgumentList $Instancia,$Base,$block -ScriptBlock {
    param($server,$Base,$sql)
    & sqlcmd -S $server -E -C -l 5 -b -d $Base -Q $sql
    if ($LASTEXITCODE) { throw 'Falló la sesión que retiene el bloqueo' }
}
try {
    $held = $false
    for ($iteration=0; $iteration -lt 15; $iteration++) {
        if ((Query "SELECT APPLOCK_TEST('public',N'$resource','Exclusive','Session');") -eq '0') {
            $held = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (!$held) { throw 'La sesión secundaria no obtuvo el bloqueo.' }
    & $Dtexec /Project $Ispac /Package ETL_Orders.dtsx /Reporting EWI 2>&1 |
        Set-Content "$out/dtexec.log"
    if ($LASTEXITCODE -ne 1 -or !(Select-String -Path "$out/dtexec.log" -SimpleMatch BATCH_LOCK_TIMEOUT)) {
        throw 'DTExec no devolvió el fallo de contención esperado.'
    }
    Receive-Job $job -Wait -ErrorAction Stop | Out-Null
    $after = Query $query
    if ($before -cne $after) { throw 'El lote cambió durante la prueba de contención.' }
    "APPLOCK_TEST=0; DTExec=1; BATCH_LOCK_TIMEOUT; lote intacto: $after" |
        Tee-Object "$out/resultado.log"
} finally {
    if ($job.State -eq 'Running') { Stop-Job $job }
    Remove-Job $job
}
