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
| M7 Performance pass | Pooling, MultiMesh swarms, LOD, benchmark mode | Done |
| M8 Polish | Audio, settings, menus, Windows export | Done |

## Later (designed for, not built)

- **Third-person camera:** a `ThirdPersonRig` next to `FirstPersonRig`. The `V` key is reserved.
- **Mods folder:** `AssetResolver` already supports override roots. Still needed: scanning a `mods/` folder next to the executable, runtime loading of external `.glb` (GLTFDocument) and images, and merging mod data files into `DataLoader`.
- **Story:** stage briefings and setting text are data, so a campaign narrative can be added without code changes.
- **ADS/zoom:** an optional zoom key, possibly unlocked by an upgrade.
- **Audio:** recorded voice alerts, composed music, real sound effects in place of the generated ones.
- **Gamepad support.**
- **Graphics left over from M6:** heat distortion on beams, orbital debris, decals, real PBR texture sets for terrain and hulls.
- **FSR 4 (parked by Marko on 2026-11-28, to pick up later):** tested with OptiScaler 0.9.5 on DirectX 12. It loads (the game already uses the system `d3d12.dll` and `dxgi.dll`, and the export is exe plus pck) but reports "FSR Hooks: Don't Exist": Godot's FSR 2 is compiled into the exe and never calls an upscaler library, so there is nothing to take over. Splitting the export into more DLLs would not change that. Untested: OptiScaler's "Use Fsr2 Pattern Matching" option (expected not to work, because Godot feeds FSR 2 through its own renderer layer). Ways forward, in order of effort: (1) a native C++ plugin that calls AMD's FSR 3.1 library on DirectX 12, which the Radeon driver can upgrade to FSR 4 and OptiScaler can hook; needs a C++ compiler and AMD's SDK, and may only reach native-resolution anti-aliasing because plugins work at the final resolution; (2) a custom Godot build with FSR 3.1 inside; (3) wait for a Godot version with FSR 3 or 4.
