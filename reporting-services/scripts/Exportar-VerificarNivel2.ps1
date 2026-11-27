[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SqlServerInstance,
    [Parameter(Mandatory = $true)][uri]$ReportServerUrl,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Comun.psm1') -Force

if (-not $ReportServerUrl.IsAbsoluteUri -or $ReportServerUrl.Scheme -notin @('http', 'https')) {
    throw 'ReportServerUrl debe ser una URL HTTP(S) absoluta.'
}
if (-not $ReportServerUrl.IsLoopback) {
    throw 'Por seguridad, este exportador solo envía credenciales Windows a endpoints de loopback.'
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$reportsDirectory = Join-Path $repoRoot 'reporting-services\reports'
$datasetsDirectory = Join-Path $repoRoot 'reporting-services\datasets'
$sqlTrust = @{}
if ($TrustServerCertificate.IsPresent) { $sqlTrust['TrustServerCertificate'] = $true }

$range = Invoke-OlistSqlTable -SqlServerInstance $SqlServerInstance -Database 'BI_OLIST' -Query @'
SELECT CONVERT(date, MIN(f.fecha)) AS fecha_minima, CONVERT(date, MAX(f.fecha)) AS fecha_maxima
FROM dw.FactPedidos AS p
JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
WHERE p.fecha_compra_key <> -1;
'@ @sqlTrust
if ($range.Rows.Count -ne 1 -or $range.Rows[0].IsNull('fecha_minima') -or $range.Rows[0].IsNull('fecha_maxima')) {
    throw 'No se pudo determinar el rango histórico de compra para R07.'
}
$r07Start = ([datetime]$range.Rows[0]['fecha_minima']).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$r07End = ([datetime]$range.Rows[0]['fecha_maxima']).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

$audit = Invoke-OlistSqlTable -SqlServerInstance $SqlServerInstance -Database 'BI_OLIST' -Query @'
SELECT CONVERT(date, MIN(started_at)) AS fecha_minima, CONVERT(date, MAX(started_at)) AS fecha_maxima
FROM audit.Batch;
'@ @sqlTrust
if ($audit.Rows.Count -ne 1 -or $audit.Rows[0].IsNull('fecha_minima') -or $audit.Rows[0].IsNull('fecha_maxima')) {
    throw 'No se pudo determinar el rango real de lotes de auditoría para R10.'
}
$r10Start = ([datetime]$audit.Rows[0]['fecha_minima']).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$r10End = ([datetime]$audit.Rows[0]['fecha_maxima']).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

# El identificador se usa solo en memoria para exportar R08; no se escribe en consola, URL registrada ni manifiesto.
$multiLineOrder = Invoke-OlistSqlTable -SqlServerInstance $SqlServerInstance -Database 'BI_OLIST' -Query @'
SELECT TOP (1) order_id
FROM dw.FactDetallePedido
GROUP BY order_id
HAVING COUNT_BIG(*) > 1
ORDER BY order_id;
'@ @sqlTrust
if ($multiLineOrder.Rows.Count -ne 1) { throw 'No existe un pedido con varias líneas para la prueba R08.' }
$r08OrderId = [string]$multiLineOrder.Rows[0]['order_id']

$reports = @(
    [pscustomobject]@{ Id = 'R01'; Stem = 'R01_ResumenGerencial'; Path = '/OLIST360/01_Gerencia/R01_ResumenGerencial'; Suffix = '2017'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoCliente = '__TODOS__' }; Display = '2017; clientes=__TODOS__' },
    [pscustomobject]@{ Id = 'R02'; Stem = 'R02_ConsolidadoMensual'; Path = '/OLIST360/01_Gerencia/R02_ConsolidadoMensual'; Suffix = '2017'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoCliente = '__TODOS__'; Categoria = '__TODOS__' }; Display = '2017; clientes/categorías=__TODOS__' },
    [pscustomobject]@{ Id = 'R03'; Stem = 'R03_RankingVendedores'; Path = '/OLIST360/02_Comercial/R03_RankingVendedores'; Suffix = '2017_top10'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoVendedor = '__TODOS__'; TopN = '10' }; Display = '2017; vendedores=__TODOS__; top=10' },
    [pscustomobject]@{ Id = 'R04'; Stem = 'R04_RendimientoCategorias'; Path = '/OLIST360/02_Comercial/R04_RendimientoCategorias'; Suffix = '2017'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; Categoria = '__TODOS__' }; Display = '2017; categorías=__TODOS__' },
    [pscustomobject]@{ Id = 'R05'; Stem = 'R05_EntregasRetrasadas'; Path = '/OLIST360/03_Operaciones/R05_EntregasRetrasadas'; Suffix = '2017_SP_retraso1'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoCliente = 'SP'; DiasRetrasoMin = '1' }; Display = '2017; estado=SP; retraso_mínimo=1' },
    [pscustomobject]@{ Id = 'R06'; Stem = 'R06_Satisfaccion'; Path = '/OLIST360/03_Operaciones/R06_Satisfaccion'; Suffix = '2017_SP_notas1a5'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoCliente = 'SP'; NotaMin = '1'; NotaMax = '5' }; Display = '2017; estado=SP; notas=1..5' },
    [pscustomobject]@{ Id = 'R07'; Stem = 'R07_ImportesPagados'; Path = '/OLIST360/02_Comercial/R07_ImportesPagados'; Suffix = 'historico'; Params = [ordered]@{ Desde = $r07Start; Hasta = $r07End; EstadoPedido = '__TODOS__' }; Display = "histórico=$r07Start..$r07End; estados=__TODOS__" },
    [pscustomobject]@{ Id = 'R08'; Stem = 'R08_FichaPedido'; Path = '/OLIST360/03_Operaciones/R08_FichaPedido'; Suffix = 'pedido_multilinea_redactado'; Params = [ordered]@{ OrderId = $r08OrderId }; Display = 'pedido existente con varias líneas; OrderId redactado' },
    [pscustomobject]@{ Id = 'R09'; Stem = 'R09_DesempenoRegional'; Path = '/OLIST360/03_Operaciones/R09_DesempenoRegional'; Suffix = '2017_SP_sao_paulo'; Params = [ordered]@{ Desde = '2017-01-01'; Hasta = '2017-12-31'; EstadoCliente = 'SP'; Ciudad = 'sao paulo' }; Display = '2017; estado=SP; ciudad=sao paulo' },
    [pscustomobject]@{ Id = 'R10'; Stem = 'R10_AuditoriaETL'; Path = '/OLIST360/04_Auditoria/R10_AuditoriaETL'; Suffix = 'auditoria_historica'; Params = [ordered]@{ DesdeEjecucion = $r10Start; HastaEjecucion = $r10End; Fuente = '__TODOS__'; EstadoLote = '__TODOS__' }; Display = "auditoría=$r10Start..$r10End; fuente/estado=__TODOS__" }
)

function Export-RenderedFile {
    param(
        [Parameter(Mandatory = $true)][uri]$BaseUrl,
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$Format,
        [Parameter(Mandatory = $true)][string]$Extension
    )

    $query = [uri]::EscapeDataString([string]$Report.Path) + '&rs:Command=Render&rs:Format=' + [uri]::EscapeDataString($Format)
    foreach ($key in $Report.Params.Keys) {
        $query += '&' + [uri]::EscapeDataString([string]$key) + '=' + [uri]::EscapeDataString([string]$Report.Params[$key])
    }
    $url = $BaseUrl.AbsoluteUri.TrimEnd('/') + '?' + $query
    $destination = Join-Path $OutputDirectory ($Report.Stem + '_' + $Report.Suffix + $Extension)

    $request = @{ Uri = $url; UseDefaultCredentials = $true; TimeoutSec = 180 }
    if ($PSVersionTable.PSVersion.Major -le 5) { $request['UseBasicParsing'] = $true }
    else { $request['AllowUnencryptedAuthentication'] = $true }
    $response = Invoke-WebRequest @request
    if ($response.StatusCode -ne 200) { throw "$($Report.Id) $Format respondió HTTP $($response.StatusCode)." }
    $contentType = [string]$response.Headers['Content-Type']
    if ($null -eq $response.RawContentStream) { throw "$($Report.Id) $Format no devolvió un cuerpo binario." }
    $response.RawContentStream.Position = 0
    $file = [System.IO.File]::Create($destination)
    try { $response.RawContentStream.CopyTo($file) } finally { $file.Dispose() }

    $bytes = [System.IO.File]::ReadAllBytes($destination)
    if ($bytes.Length -lt 8) { throw "$($Report.Id) $Format devolvió un archivo vacío o truncado." }
    if ($Extension -eq '.pdf') {
        $signature = [Text.Encoding]::ASCII.GetString($bytes, 0, 5)
        if ($signature -ne '%PDF-') { throw "$($Report.Id) no devolvió una firma PDF; Content-Type=$contentType." }
    } else {
        if ($bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) { throw "$($Report.Id) no devolvió un XLSX OOXML; Content-Type=$contentType." }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($destination)
        try {
            $workbookEntry = $archive.GetEntry('xl/workbook.xml')
            if ($null -eq $archive.GetEntry('[Content_Types].xml') -or $null -eq $workbookEntry) {
                throw "$($Report.Id) no contiene las partes OOXML requeridas."
            }
            $workbookXml = [System.Xml.XmlDocument]::new()
            $stream = $workbookEntry.Open()
            try { $workbookXml.Load($stream) } finally { $stream.Dispose() }
            $sheetNames = @($workbookXml.SelectNodes("//*[local-name()='sheet']") | ForEach-Object { $_.GetAttribute('name') })
            if ($sheetNames.Count -eq 0) { throw "$($Report.Id) XLSX no contiene hojas." }
            $sheets = $sheetNames -join '|'
        } finally { $archive.Dispose() }
    }

    $fileInfo = Get-Item -LiteralPath $destination
    [pscustomobject]@{
        fecha_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
        informe = $Report.Id
        ruta_catalogo = $Report.Path
        parametros_redactados = $Report.Display
        sha256_rdl = (Get-FileHash -LiteralPath (Join-Path $reportsDirectory ($Report.Stem + '.rdl')) -Algorithm SHA256).Hash
        formato = $Format
        archivo = $fileInfo.Name
        content_type = $contentType
        bytes = $fileInfo.Length
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        hojas = if ($Extension -eq '.xlsx') { $sheets } else { '' }
        estado = 'PASS-formato; pendiente apertura/inspección visual'
    }
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($report in $reports) {
    $rdlFile = Join-Path $reportsDirectory ($report.Stem + '.rdl')
    if (-not (Test-Path -LiteralPath $rdlFile)) { throw "Falta el RDL fuente $($report.Stem)." }
    $results.Add((Export-RenderedFile -BaseUrl $ReportServerUrl -Report $report -Format 'PDF' -Extension '.pdf'))
    $results.Add((Export-RenderedFile -BaseUrl $ReportServerUrl -Report $report -Format 'EXCELOPENXML' -Extension '.xlsx'))
    Write-Output ("$($report.Id): PDF y XLSX generados; parámetros: $($report.Display)")
}

$manifestPath = Join-Path $OutputDirectory 'manifiesto-exportaciones.csv'
$results | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
Write-Output ("Exportaciones: $($results.Count) archivos; manifiesto local: $manifestPath")
