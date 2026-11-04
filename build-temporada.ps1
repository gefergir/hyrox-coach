# Compila Mi Temporada para el Forerunner 165 Music y deja el .prg en watch-temporada\bin.
# Uso: .\build-temporada.ps1 -BaseUrl "https://TU_USUARIO.github.io/hyrox-coach/" -DevKey "C:\ruta\developer_key"
param(
    [string]$BaseUrl = "",
    [string]$DevKey = "$HOME\.garmin\developer_key",
    [string]$Device = "fr165m"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$app = Join-Path $root "watch-temporada"

$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
$sdk = Get-ChildItem $sdkRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
if (-not $sdk) { throw "No encuentro el SDK en $sdkRoot. Instálalo con el SDK Manager de Connect IQ." }
$monkeyc = Join-Path $sdk.FullName "bin\monkeyc.bat"
if (-not (Test-Path $DevKey)) { throw "No encuentro la clave de desarrollador en $DevKey." }
if ($BaseUrl -ne "" -and -not $BaseUrl.EndsWith("/")) { $BaseUrl += "/" }

# La agenda, los retos y las sugerencias publicados se incluyen como copia inicial para funcionar sin conexión.
Copy-Item (Join-Path $root "docs\agenda.json") (Join-Path $app "resources\agenda_inicial.json") -Force
Copy-Item (Join-Path $root "docs\retos.json") (Join-Path $app "resources\retos_inicial.json") -Force
Copy-Item (Join-Path $root "docs\sugerencias.json") (Join-Path $app "resources\sugerencias_inicial.json") -Force
Copy-Item (Join-Path $root "docs\curiosidades.json") (Join-Path $app "resources\curiosidades_inicial.json") -Force

$config = Join-Path $app "source\Config.mc"
$original = Get-Content $config -Raw -Encoding UTF8
try {
    $updated = $original -replace 'const BASE_URL = ".*";', "const BASE_URL = `"$BaseUrl`";"
    [IO.File]::WriteAllText($config, $updated, (New-Object Text.UTF8Encoding $false))

    New-Item -ItemType Directory -Force (Join-Path $app "bin") | Out-Null
    $output = Join-Path $app "bin\MiTemporada.prg"
    & $monkeyc -d $Device -f (Join-Path $app "monkey.jungle") -o $output -y $DevKey -l 0
    if ($LASTEXITCODE -ne 0) { throw "La compilación ha fallado." }
    Write-Host "Listo: $output"
}
finally {
    [IO.File]::WriteAllText($config, $original, (New-Object Text.UTF8Encoding $false))
}
