# Changelog

Updated at every merge to `main`.

## M0: Setup (2026-11-21)

- Godot 4.7.2 project (Forward+, Jolt physics, GDScript), pinned in `project.godot` and `README.md`.
- Folder structure from the build spec, `.gitignore`, Git LFS rules in `.gitattributes`.
- Data pipeline: `DataLoader`, `DataSchema`, `DataValidator`, `DataReport`; schemas and file index in `data/schemas/`.
- First config files: power, economy, difficulty, turret, graphics presets, asset manifest.
- `AssetResolver` (asset IDs, fallbacks, override-root hook for future mods).
- `EventBus` and `GameData` autoloads; F5 hot-reload of data in debug builds.
- Command-line tools: `tools/validate_data.ps1`, `tools/run_tests.ps1`, `tools/godot.ps1`.
- GUT 9.7.1 with 18 unit tests for the schema checker, loader and validator.
- Docs: design, data formats, asset conventions, art brief, decisions, roadmap, performance log.
