# Roadmap

## Milestones

| Milestone | Scope | Status |
|---|---|---|
| M0 Setup | Repo structure, Godot project, data loader and validator, tests | Done |
| M1 Core turret and shooting | Camera rig, turret arc, Pulse Laser + Micro-Missiles, heat, HUD, target dummies | Done |
| M2 Enemies and stages | Enemy base, 3 behaviours, drones/interceptors/bombers, wave director, stages 1 to 3, hull and game over | Done |
| M3 Shields and power | Shield system and dome VFX, power split | Done |
| M4 Economy, shop and tech tree | Rewards, shop UI, tech tree, loadout, saving | Done |
| M5 Content pass | All weapons and enemies, stages 1 to 10, bosses, endless | Done |
| M6 Graphics pass | Environment, lighting, VFX, presets, upscaling, HUD polish | Done |
| M7 Performance pass | Pooling, MultiMesh swarms, LOD, benchmark mode | Done, awaiting approval |
| M8 Polish | Audio, settings, menus, Windows export | Next |

## Later (designed for, not built)

- **Third-person camera:** a `ThirdPersonRig` next to `FirstPersonRig`. The `V` key is reserved.
- **Mods folder:** `AssetResolver` already supports override roots. Still needed: scanning a `mods/` folder next to the executable, runtime loading of external `.glb` (GLTFDocument) and images, and merging mod data files into `DataLoader`.
- **Story:** stage briefings and setting text are data, so a campaign narrative can be added without code changes.
- **ADS/zoom:** an optional zoom key, possibly unlocked by an upgrade.
- **Respec refund:** set `economy.json: respec_refund_ratio` back to 0.75 when testing is over.
- **Graphics left over from M6:** heat distortion on beams, orbital debris, decals, real PBR texture sets for terrain and hulls.
- **Renderer option (asked by Marko, for M8):** let the player switch between Vulkan and DirectX 12 in the final build (settings menu plus a launch option; the engine already runs on both, see `--rendering-driver d3d12`). Marko wants to try OptiScaler on DirectX 12 for FSR 4; that may not work, because Godot builds FSR 2 in and has no separate upscaler library to hook.
