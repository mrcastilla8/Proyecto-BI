[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][uri]$ReportServerUrl,
    [ValidatePattern('^/OLIST360/')][string]$ReportPath = '/OLIST360/Pruebas/PRE_G0_Humo',
    [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetTempPath()) 'OLIST360-SSRS')
)

$ErrorActionPreference = 'Stop'

function Get-RenderedFile {
    param([uri]$BaseUrl, [string]$Path, [string]$Format, [string]$Extension, [string]$Destination)

    $escapedPath = [uri]::EscapeDataString($Path)
    $url = $BaseUrl.AbsoluteUri.TrimEnd('/') + '?' + $escapedPath + '&rs:Command=Render&rs:Format=' + [uri]::EscapeDataString($Format)
    $response = Invoke-WebRequest -Uri $url -UseDefaultCredentials -UseBasicParsing -TimeoutSec 90
    if ($response.StatusCode -ne 200) { throw "Render $Format devolvió HTTP $($response.StatusCode)." }
    $contentType = [string]$response.Headers['Content-Type']
    $response.RawContentStream.Position = 0
    $file = [System.IO.File]::Create($Destination)
    try { $response.RawContentStream.CopyTo($file) } finally { $file.Dispose() }
    if ((Get-Item -LiteralPath $Destination).Length -lt 8) { throw "La salida $Format está vacía o truncada." }

    $bytes = [System.IO.File]::ReadAllBytes($Destination)
    if ($Extension -eq '.pdf') {
        $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length))
        if ($signature -ne '%PDF-') { throw "La respuesta de $Format no contiene firma PDF (Content-Type: $contentType)." }
    } elseif ($Extension -eq '.xlsx') {
        if ($bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) { throw "La respuesta de $Format no es un ZIP XLSX (Content-Type: $contentType)." }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Destination)
        try {
            if ($null -eq $archive.GetEntry('[Content_Types].xml') -or $null -eq $archive.GetEntry('xl/workbook.xml')) {
                throw 'El ZIP no contiene las partes mínimas de un libro Excel Open XML.'
            }
        } finally { $archive.Dispose() }
    }

    $hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    [pscustomobject]@{ formato = $Format; archivo = [System.IO.Path]::GetFileName($Destination); bytes = (Get-Item -LiteralPath $Destination).Length; content_type = $contentType; sha256 = $hash }
}

if (-not $ReportServerUrl.IsAbsoluteUri -or $ReportServerUrl.Scheme -notin @('http', 'https')) { throw 'ReportServerUrl debe ser una URL HTTP(S) absoluta.' }
if (-not $ReportServerUrl.IsLoopback) { throw 'Por seguridad, este exportador solo envía credenciales Windows a endpoints de loopback.' }
if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }

$results = @(
    Get-RenderedFile -BaseUrl $ReportServerUrl -Path $ReportPath -Format 'PDF' -Extension '.pdf' -Destination (Join-Path $OutputDirectory 'PRE_G0_Humo.pdf')
    Get-RenderedFile -BaseUrl $ReportServerUrl -Path $ReportPath -Format 'EXCELOPENXML' -Extension '.xlsx' -Destination (Join-Path $OutputDirectory 'PRE_G0_Humo.xlsx')
)
$results
