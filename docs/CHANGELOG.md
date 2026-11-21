# Changelog

Updated at every merge to `main`.

## M1: Core turret and shooting (2026-11-21)

- First-person turret with a limited aim arc (yaw ±80°, pitch −5° to +85°), soft resistance and HUD markers at the limits.
- `CameraRig` abstraction with `FirstPersonRig`: separate viewmodel camera and FOV, recoil kick, screen shake, Hor+ FOV for ultrawide.
- Weapon framework: data files, `Weapon` base, heat with overheat lockout, archetypes `hitscan_pulse` and `homing`.
- Pulse Laser Mk I (LMB) and Micro-Missile Pod (RMB, lock-on, per-stage ammo); both fire together.
- Damage rules: shields, armour with pierce, resistances, splash falloff.
- Pooled effects (tracers, flashes, explosions) and pooled homing missiles with swept collision.
- HUD: crosshair, heat arcs, missile ammo/reload, lock brackets, hit and kill markers, arc map, hull bar.
- Test range with 14 practice targets from data; placeholder `.glb` models built by a script.
- Data-driven input bindings; `UserSettings` autoload (sensitivity, invert Y, turret weight, FOV, shake).
- Automated demo with fps logging (`tools/run_demo.ps1`). 41 unit tests.

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
