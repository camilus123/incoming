# Roadmap

## Milestones

| Milestone | Scope | Status |
|---|---|---|
| M0 Setup | Repo structure, Godot project, data loader and validator, tests | Done |
| M1 Core turret and shooting | Camera rig, turret arc, Pulse Laser + Micro-Missiles, heat, HUD, target dummies | Done, awaiting approval |
| M2 Enemies and stages | Enemy base, 3 behaviours, drones/interceptors/bombers, wave director, stages 1 to 3, hull and game over | Next |
| M3 Shields and power | Shield system and dome VFX, power split | |
| M4 Economy, shop and tech tree | Rewards, shop UI, tech tree, loadout, saving | |
| M5 Content pass | All weapons and enemies, stages 1 to 10, bosses, endless | |
| M6 Graphics pass | Environment, lighting, VFX, presets, upscaling, HUD polish | |
| M7 Performance pass | Pooling, MultiMesh swarms, LOD, benchmark mode | |
| M8 Polish | Audio, settings, menus, Windows export | |

## Later (designed for, not built)

- **Third-person camera:** a `ThirdPersonRig` next to `FirstPersonRig`. The `V` key is reserved.
- **Mods folder:** `AssetResolver` already supports override roots. Still needed: scanning a `mods/` folder next to the executable, runtime loading of external `.glb` (GLTFDocument) and images, and merging mod data files into `DataLoader`.
- **Story:** stage briefings and setting text are data, so a campaign narrative can be added without code changes.
- **ADS/zoom:** an optional zoom key, possibly unlocked by an upgrade.
- **Respec refund:** set `economy.json: respec_refund_ratio` back to 0.75 when testing is over.
