# Runs the automated demo: the turret aims and fires by itself, then prints a PERF line
# (average fps and 1 % lows) and quits. V-Sync is off during the demo.
#   .\tools\run_demo.ps1                       fullscreen, 20 seconds
#   .\tools\run_demo.ps1 -Seconds 12 -ScreenshotDir C:\temp\shots -Windowed
#   .\tools\run_demo.ps1 -Seconds 60 -Stage 3 -God     busiest stage, for fps numbers
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Seconds = 20,
    [string]$ScreenshotDir = '',
    [switch]$Windowed,
    [int]$Stage = 1,
    [switch]$God,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs = @()
)

$godotArgs = @()
if (-not $Windowed) { $godotArgs += '--fullscreen' }
$godotArgs += @('++', '--auto-demo', "--demo-seconds=$Seconds", "--stage=$Stage")
if ($God) { $godotArgs += '--god' }
if ($ScreenshotDir) { $godotArgs += "--screenshot-dir=$ScreenshotDir" }
$godotArgs += @($GameArgs | Where-Object { $_ -ne '++' })

& (Join-Path $PSScriptRoot 'godot.ps1') @godotArgs
exit $LASTEXITCODE
