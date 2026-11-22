# Runs the benchmark: a scripted heavy fight played by the automatic gunner.
# Prints average fps, median and 1 % lows, and writes a JSON file with every frame time.
#   .\tools\run_benchmark.ps1                      default preset, fullscreen
#   .\tools\run_benchmark.ps1 -Preset high         a specific preset
#   .\tools\run_benchmark.ps1 -OutDir C:\temp\bench  where the result file goes
#   .\tools\run_benchmark.ps1 -Driver d3d12        Vulkan (default) or DirectX 12
# V-Sync is off during the run. Turn off any frame rate cap in the graphics driver first.
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Preset = '',
    [string]$OutDir = '',
    [string]$Driver = '',
    [switch]$Windowed,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs = @()
)

$godotArgs = @()
if ($Driver) { $godotArgs += @('--rendering-driver', $Driver) }
if (-not $Windowed) { $godotArgs += '--fullscreen' }
$godotArgs += @('++', '--benchmark')
if ($Preset) { $godotArgs += "--preset=$Preset" }
if ($OutDir) { $godotArgs += "--benchmark-out=$OutDir" }
$godotArgs += @($GameArgs | Where-Object { $_ -ne '++' })

& (Join-Path $PSScriptRoot 'godot.ps1') @godotArgs
exit $LASTEXITCODE
