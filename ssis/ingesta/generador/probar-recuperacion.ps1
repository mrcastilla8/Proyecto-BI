param(
    [Parameter(Mandatory)][string]$Proyecto,
    [Parameter(Mandatory)][string]$Fixtures,
    [Parameter(Mandatory)][string]$Evidencia,
    [Parameter(Mandatory)][string]$ArchivosLocalDb,
    [ValidateSet('BI_OLIST','BI_OLIST_VALIDACION_TEXTO')][string]$Base = 'BI_OLIST',
    [string]$Instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
)
$ErrorActionPreference = 'Stop'
$output = (New-Item -ItemType Directory $Evidencia).FullName
$csv = (New-Item -ItemType Directory "$output/fixtures").FullName
Get-ChildItem -LiteralPath $Fixtures -File -Filter '*.csv' | Copy-Item -Destination $csv
$utf8 = [Text.UTF8Encoding]::new($false)
$stamp = [guid]::NewGuid().ToString('N').Substring(0,12)
$review = Join-Path $csv 'olist_order_reviews_dataset.csv'
$translation = Join-Path $csv 'product_category_name_translation.csv'
$reviewData = [IO.File]::ReadAllText($review).Replace('R-01', "RECOVERY-$stamp")
$translationData = [IO.File]::ReadAllText($translation).Replace('beleza_saude', "recovery_$stamp")
[IO.File]::WriteAllText($review, $reviewData, $utf8)
[IO.File]::WriteAllText($translation, $translationData, [Text.UTF8Encoding]::new($true))
$reviewHash = (Get-FileHash -LiteralPath $review).Hash.ToLowerInvariant()
$translationHash = (Get-FileHash -LiteralPath $translation).Hash.ToLowerInvariant()
$databasePath = (Resolve-Path -LiteralPath $ArchivosLocalDb).Path.TrimEnd('\').Replace("'","''") + '\'
$guard = "SET NOCOUNT ON; IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>N'$Base' OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN(N'$databasePath'))<>N'$databasePath') THROW 51900,'Destino fuera del laboratorio',1;"
$lookup = "DECLARE @id bigint=(SELECT batch_id FROM audit.Batch WHERE source_name=N'OrderReviews' AND source_sha256='$reviewHash');"
function Invoke-Case([string]$sql,[string]$log) {
    $result = @(& sqlcmd -S $Instancia -E -C -l 10 -b -r 1 -W -h -1 -s '|' -d $Base -Q "$guard $lookup $sql")
    if ($LASTEXITCODE) { throw 'No se verificó el estado esperado de la recuperación.' }
    $result | Set-Content "$output/$log"
    $result
}
$injected = Join-Path $output 'proyecto-inyectado'
& (Join-Path $PSScriptRoot 'generar.ps1') -Salida $injected -Plantilla (Join-Path $Proyecto 'ETL_Olist_Ingesta.dtproj') -ActualizarPublicacion -FalloEn OrderReviews
$common = @{ CsvRoot=$csv; ArchivosLocalDb=$ArchivosLocalDb; Instancia=$Instancia; Base=$Base }
& (Join-Path $PSScriptRoot 'probar.ps1') -Proyecto $injected -Evidencia "$output/fallo" -FalloEsperado @common
if (-not (Select-String -LiteralPath "$output/fallo/fallo.log" -SimpleMatch 'Fallo inyectado')) {
    throw 'El fallo de DTExec no corresponde a la inyección después de escribir.'
}
$failed = @(Invoke-Case @"
IF NOT EXISTS(SELECT 1 FROM audit.Batch WHERE batch_id=@id AND status='FAILED' AND error_message='PUBLICAR/51999')
    THROW 51990,'Lote de fallo ausente',1;
IF EXISTS(SELECT 1 FROM stg.OrderReviews WHERE batch_id=@id) OR EXISTS(SELECT 1 FROM audit.Reject WHERE batch_id=@id)
    THROW 51991,'Rollback incompleto',1;
IF EXISTS(SELECT 1 FROM audit.Batch WHERE source_sha256='$translationHash') THROW 51992,'Maestro no se detuvo',1;
SELECT batch_id,status,rows_read,rows_accepted,rows_rejected,error_message FROM audit.Batch WHERE batch_id=@id;
"@ 'rollback.log')

& (Join-Path $PSScriptRoot 'probar.ps1') -Proyecto $Proyecto -Evidencia "$output/recuperacion" @common
$id = ($failed[0] -split '\|')[0]
if ($id -notmatch '^\d+$') { throw 'No se identificó el lote fallido' }
Invoke-Case "IF @id<>$id OR NOT EXISTS(SELECT 1 FROM audit.Batch WHERE batch_id=@id AND status='COMPLETE') THROW 51993,'No se recuperó el mismo lote',1; SELECT batch_id,status,rows_read,rows_accepted,rows_rejected FROM audit.Batch WHERE batch_id=@id;" 'recuperado.log'
