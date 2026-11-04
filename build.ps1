# Compila la app para el Forerunner 165 Music y deja el .prg en watch\bin.
# Uso: .\build.ps1 -PlanUrl "https://TU_USUARIO.github.io/hyrox-coach/plan.json" -DevKey "C:\ruta\developer_key"
param(
    [string]$PlanUrl = "",
    [string]$DevKey = "$HOME\.garmin\developer_key",
    [string]$Device = "fr165m"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$watch = Join-Path $root "watch"

$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
$sdk = Get-ChildItem $sdkRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
if (-not $sdk) { throw "No encuentro el SDK en $sdkRoot. Instálalo con el SDK Manager de Connect IQ." }
$monkeyc = Join-Path $sdk.FullName "bin\monkeyc.bat"
if (-not (Test-Path $DevKey)) { throw "No encuentro la clave de desarrollador en $DevKey." }

Copy-Item (Join-Path $root "docs\plan.json") (Join-Path $watch "resources\plan_inicial.json") -Force

$config = Join-Path $watch "source\Config.mc"
$original = Get-Content $config -Raw -Encoding UTF8
try {
    $updated = $original -replace 'const PLAN_URL = ".*";', "const PLAN_URL = `"$PlanUrl`";"
    [IO.File]::WriteAllText($config, $updated, (New-Object Text.UTF8Encoding $false))

    New-Item -ItemType Directory -Force (Join-Path $watch "bin") | Out-Null
    $output = Join-Path $watch "bin\HyroxCoach.prg"
    & $monkeyc -d $Device -f (Join-Path $watch "monkey.jungle") -o $output -y $DevKey -l 0
    if ($LASTEXITCODE -ne 0) { throw "La compilación ha fallado." }
    Write-Host "Listo: $output"
}
finally {
    [IO.File]::WriteAllText($config, $original, (New-Object Text.UTF8Encoding $false))
}
