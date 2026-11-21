# Runs the automated tests (GUT) headless. Exit code 0 = all passed.
& (Join-Path $PSScriptRoot 'godot.ps1') --headless --script res://addons/gut/gut_cmdln.gd
exit $LASTEXITCODE
