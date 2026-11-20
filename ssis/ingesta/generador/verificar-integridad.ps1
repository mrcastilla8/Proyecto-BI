param(
    [Parameter(Mandatory)][string]$Perfil,
    [Parameter(Mandatory)][string]$HashesFixtures,
    [Parameter(Mandatory)][string]$ArchivosLocalDb,
    [Parameter(Mandatory)][string]$Consulta,
    [ValidateSet('BI_OLIST','BI_OLIST_VALIDACION_TEXTO')][string]$Base = 'BI_OLIST',
    [string]$Instancia = '(localdb)\BI_OLIST_ISSUE1_PROTO'
)
$ErrorActionPreference = 'Stop'
if ($Instancia -notmatch '^\(localdb\)\\[a-zA-Z0-9_-]+$') { throw 'Instancia LocalDB no válida.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$contract = Get-Content (Join-Path $repo 'contracts/modelo-dimensional.v1.json') -Raw | ConvertFrom-Json
$sources = @($contract.staging_sources | ForEach-Object { $_.table.Substring(4) })
$profileRows = @(Get-Content -LiteralPath $Perfil -Raw | ConvertFrom-Json)
if ($profileRows.Count -ne 9) { throw 'Perfil incompleto.' }
$dbPath = (Resolve-Path -LiteralPath $ArchivosLocalDb).Path.TrimEnd('\').Replace("'","''") + '\'
$parts = @(
    "SET NOCOUNT ON; IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>N'$Base' OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN(N'$dbPath'))<>N'$dbPath') THROW 51900,'Destino fuera del laboratorio',1;",
    "CREATE TABLE #Verificacion(fuente sysname,lote bigint,estado varchar(12),leidas bigint,aceptadas bigint,rechazadas bigint,staging bigint,ordinal_min bigint,ordinal_max bigint);"
)
foreach ($row in $profileRows) {
    $name = $row.source
    $hash = $row.sha256
    if ($name -cnotin $sources -or $hash -notmatch '^[0-9a-f]{64}$') { throw 'Fuente o hash inválidos.' }
    [long]$rows = $row.records
    $parts += @"
DECLARE @lot_$name bigint=(SELECT batch_id FROM audit.Batch WHERE source_name='$name' AND source_sha256='$hash' AND status='COMPLETE' AND contract_version='1.0.0');
INSERT #Verificacion SELECT '$name',b.batch_id,b.status,b.rows_read,b.rows_accepted,b.rows_rejected,s.n,s.min_row,s.max_row
FROM audit.Batch b CROSS APPLY (SELECT COUNT_BIG(*) n,MIN(source_row_number) min_row,MAX(source_row_number) max_row FROM stg.[$name] WHERE batch_id=b.batch_id) s
WHERE b.batch_id=@lot_$name;
IF NOT EXISTS (SELECT 1 FROM #Verificacion WHERE lote=@lot_$name AND leidas=$rows AND leidas=aceptadas+rechazadas AND aceptadas=staging AND ordinal_min=1 AND ordinal_max=leidas)
    THROW 51960,'Conteo u ordinales inválidos: $name',1;
"@
}
$geo = $profileRows | Where-Object source -eq Geolocation
$reviews = $profileRows | Where-Object source -eq OrderReviews
$fixtureHash = (Import-Csv -LiteralPath $HashesFixtures | Where-Object Source -eq OrderReviews).SHA256
if ($fixtureHash -notmatch '^[0-9a-f]{64}$') { throw 'Falta el hash de la fixture Reviews.' }
$longText = ('長' * 3770) + [char]34 + ", ñ" + [char]13 + [char]10 + ('ñ' * 224)
$algorithm = [Security.Cryptography.SHA256]::Create()
try { $longHash = [Convert]::ToHexString($algorithm.ComputeHash([Text.Encoding]::Unicode.GetBytes($longText))) }
finally { $algorithm.Dispose() }
$parts += @"
SELECT * FROM #Verificacion ORDER BY lote;
SELECT SUM(leidas) leidas,SUM(aceptadas) aceptadas,SUM(rechazadas) rechazadas,SUM(staging) staging FROM #Verificacion;
DECLARE @geo bigint=(SELECT SUM(n-1) FROM (SELECT COUNT_BIG(*) n FROM stg.Geolocation WHERE batch_id=@lot_Geolocation
    GROUP BY geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,geolocation_city COLLATE Latin1_General_100_BIN2,geolocation_state) g);
DECLARE @reviewDup bigint=(SELECT COUNT_BIG(*)-COUNT_BIG(DISTINCT review_id) FROM stg.OrderReviews WHERE batch_id=@lot_OrderReviews);
DECLARE @multiline bigint,@units int;
SELECT @multiline=SUM(CONVERT(bigint,CASE WHEN CHARINDEX(NCHAR(10),review_comment_message)>0 OR CHARINDEX(NCHAR(13),review_comment_message)>0 OR CHARINDEX(NCHAR(10),review_comment_title)>0 OR CHARINDEX(NCHAR(13),review_comment_title)>0 THEN 1 ELSE 0 END)),
    @units=MAX(DATALENGTH(review_comment_message)/2) FROM stg.OrderReviews WHERE batch_id=@lot_OrderReviews;
IF @geo<>$($geo.duplicate_rows_or_ids) OR @reviewDup<>$($reviews.duplicate_rows_or_ids)
    OR @multiline<>$($reviews.multiline_records) OR @units<>$($reviews.max_message_utf16_units)
    THROW 51961,'Diferencia en los casos de Geolocation o Reviews',1;
SELECT @geo geolocation_duplicadas,@reviewDup review_id_repetidos,@multiline resenas_multilinea,@units max_unidades_utf16;
DECLARE @fixture bigint=(SELECT batch_id FROM audit.Batch WHERE source_name='OrderReviews' AND source_sha256='$fixtureHash' AND status='COMPLETE');
IF NOT EXISTS(SELECT 1 FROM stg.OrderReviews WHERE batch_id=@fixture AND DATALENGTH(review_comment_message)=8000
    AND HASHBYTES('SHA2_256',review_comment_message)=0x$longHash AND review_comment_title IS NULL)
    THROW 51962,'Diferencia en texto sintético largo, Unicode o saltos',1;
SELECT @fixture fixture_reviews,4000 unidades_utf16,'SHA-256 coincide con la fixture' resultado;
DECLARE @expected TABLE(id varchar(64), titulo nvarchar(1000), mensaje nvarchar(4000));
INSERT @expected VALUES
 ('TEXTO-VACIO',NULL,NULL), ('TEXTO-ESPACIO',N' ',N'  '),
 ('TEXTO-FINAL',N'fim ',N'conte'+NCHAR(250)+N'do  '),
 ('TEXTO-UNICODE',NCHAR(173),N'a'+NCHAR(231)+NCHAR(227)+N'o, "ol'+NCHAR(225)+N'"'+NCHAR(13)+NCHAR(10)+N'segunda linha ');
IF EXISTS(SELECT 1 FROM @expected e
  WHERE NOT EXISTS(SELECT 1 FROM stg.OrderReviews s WHERE s.batch_id=@fixture AND s.review_id=e.id
    AND (s.review_comment_title IS NULL AND e.titulo IS NULL OR
      DATALENGTH(s.review_comment_title)=DATALENGTH(e.titulo) AND HASHBYTES('SHA2_256',s.review_comment_title)=HASHBYTES('SHA2_256',e.titulo))
    AND (s.review_comment_message IS NULL AND e.mensaje IS NULL OR
      DATALENGTH(s.review_comment_message)=DATALENGTH(e.mensaje) AND HASHBYTES('SHA2_256',s.review_comment_message)=HASHBYTES('SHA2_256',e.mensaje))))
   THROW 51963,'Diferencia en los casos de longitud exacta',1;
SELECT e.id,DATALENGTH(s.review_comment_title) bytes_titulo,DATALENGTH(s.review_comment_message) bytes_mensaje
FROM @expected e JOIN stg.OrderReviews s ON s.batch_id=@fixture AND s.review_id=e.id ORDER BY e.id;
SELECT COUNT_BIG(CASE WHEN order_approved_at IS NULL THEN 1 END) aprobacion_nula,
    COUNT_BIG(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 END) transportista_nulo,
    COUNT_BIG(CASE WHEN order_delivered_customer_date IS NULL THEN 1 END) entrega_nula FROM stg.Orders WHERE batch_id=@lot_Orders;
SELECT COUNT_BIG(*) clientes_zip_con_cero FROM stg.Customers WHERE batch_id=@lot_Customers AND customer_zip_code_prefix LIKE '0%';
"@
$parts -join [Environment]::NewLine | Set-Content -LiteralPath $Consulta
& sqlcmd -S $Instancia -E -C -l 10 -b -W -s '|' -d $Base -i $Consulta
exit $LASTEXITCODE
