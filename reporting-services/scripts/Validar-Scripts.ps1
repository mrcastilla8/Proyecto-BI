[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$parseErrors = [System.Collections.Generic.List[object]]::new()
$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })

foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    foreach ($errorRecord in $errors) {
        $parseErrors.Add([pscustomobject]@{ archivo = $file.Name; linea = $errorRecord.Extent.StartLineNumber; mensaje = $errorRecord.Message })
    }
}

if ($parseErrors.Count -gt 0) {
    $parseErrors
    exit 1
}

[pscustomobject]@{ estado = 'PASS'; powershell = $PSVersionTable.PSVersion.ToString(); archivos = $files.Count; detalle = 'Todos los archivos PowerShell parsean sin errores.' }
