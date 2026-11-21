# Finds the Godot executable and runs it with the given arguments from the project root.
# Set the GODOT_BIN environment variable to the Godot console executable, e.g.
#   $env:GODOT_BIN = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
# If GODOT_BIN is not set, "godot" must be on the PATH.
$ErrorActionPreference = 'Stop'

$godot = $env:GODOT_BIN
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error 'Godot not found. Set GODOT_BIN to the Godot 4.7.2 console executable or put "godot" on the PATH.'
    exit 2
}

$projectRoot = Split-Path -Parent $PSScriptRoot

# A fresh clone has no import cache yet; build it once so scripts and assets resolve.
if (-not (Test-Path (Join-Path $projectRoot '.godot'))) {
    & $godot --headless --path $projectRoot --import | Out-Null
}

& $godot --path $projectRoot @args
exit $LASTEXITCODE
