# Runs the automated demo: the turret aims and fires by itself, then prints a PERF line
# (average fps and 1 % lows) and quits. V-Sync is off during the demo.
#   .\tools\run_demo.ps1                       fullscreen, 20 seconds
#   .\tools\run_demo.ps1 -Seconds 12 -ScreenshotDir C:\temp\shots -Windowed
param(
    [int]$Seconds = 20,
    [string]$ScreenshotDir = '',
    [switch]$Windowed
)

$godotArgs = @()
if (-not $Windowed) { $godotArgs += '--fullscreen' }
$godotArgs += @('++', '--auto-demo', "--demo-seconds=$Seconds")
if ($ScreenshotDir) { $godotArgs += "--screenshot-dir=$ScreenshotDir" }

& (Join-Path $PSScriptRoot 'godot.ps1') @godotArgs
exit $LASTEXITCODE
