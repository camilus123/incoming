# Builds the Windows release into build\windows (INCOMING.exe + INCOMING.pck).
# Needs the Godot export templates for the pinned engine version
# (Godot editor: Editor > Manage Export Templates > Download and Install).
#   .\tools\export_windows.ps1            release build
#   .\tools\export_windows.ps1 -DebugBuild     debug build (F1, F3, F4, F5 keys work)
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$DebugBuild
)

$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'build\windows'
New-Item -ItemType Directory -Force $out | Out-Null
$mode = if ($DebugBuild) { '--export-debug' } else { '--export-release' }

& (Join-Path $PSScriptRoot 'godot.ps1') --headless $mode 'Windows Desktop' (Join-Path $out 'INCOMING.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path (Join-Path $out 'INCOMING.exe'))) {
    Write-Error 'Export did not produce INCOMING.exe. Are the export templates installed?'
    exit 1
}
Get-ChildItem $out | Select-Object Name, @{ Name = 'MB'; Expression = { [math]::Round($_.Length / 1MB, 1) } }
