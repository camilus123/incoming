# Validates all data files. Exit code 0 = OK, 1 = errors found.
# Optional: pass another data root, e.g.  .\tools\validate_data.ps1 res://tests/fixtures/bad_data
param([string]$DataRoot = 'res://data')

& (Join-Path $PSScriptRoot 'godot.ps1') --headless --script res://tools/validate_data.gd ++ "--data-root=$DataRoot"
exit $LASTEXITCODE
