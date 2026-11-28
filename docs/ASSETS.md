# Asset pipeline

## Rules

- Models are **glTF 2.0** (`.glb` preferred). Textures are PBR: albedo, normal, ORM (occlusion in R, roughness in G, metallic in B) and optional emission.
- 1 unit = 1 metre. Models face **−Z** (Godot forward), Y is up.
- Game code never contains file paths. It uses **asset IDs** that are looked up in `data/assets/asset_manifest.json` through `GameData.assets` (`AssetResolver`).
- To swap an asset: replace the file, or point the manifest entry at a new file. Nothing else changes as long as the new model follows the socket conventions below.
- Every third-party asset is listed in `assets/CREDITS.md` with source and licence. Only CC0 or similarly clear licences.

## Asset ID naming

`<type>.<group>.<name>[.<variant>]`, lower case, for example:

- `model.turret.base`, `model.weapon.pulse_laser`, `model.enemy.interceptor`
- `texture.env.ground_albedo`
- `audio.weapon.pulse_laser.fire`, `audio.alert.shields_down`
- `vfx.explosion.medium`

## Socket conventions

Sockets are empty nodes inside the model. Code finds them **by name**, so a replacement model only needs the same names. A trailing `_0`, `_1`, ... numbers multiples.

### Weapon and turret models

| Node | Purpose |
|---|---|
| `Pivot_Yaw` | Rotates around Y to follow the aim yaw (turret base ring) |
| `Pivot_Pitch` | Child of `Pivot_Yaw`; rotates around X to follow the aim pitch (gun cradle) |
| `ViewAnchor` | Where the first-person camera sits (child of `Pivot_Pitch`) |
| `Mount_Primary`, `Mount_Alternate` | In the turret model, children of `Pivot_Pitch`: where the primary and alternate weapon models are attached |
| `Muzzle_0`, `Muzzle_1`, ... | Barrel ends; shots, tracers and muzzle flashes start here, −Z points out of the barrel |
| `Eject_0`, ... | Shell ejection ports for kinetic weapons, −Z is the ejection direction |
| `Spin_0` | Optional: the rotating barrel cluster of spin-up weapons (turns around its own Z axis) |

### Enemy models

| Node | Purpose |
|---|---|
| `Hitbox_*` | Position and scale markers for simple collision shapes (the render mesh is never used for hits) |
| `WeakPoint_*` | Destructible subsystems (shield generators, turrets, hangar bays, engines) |
| `Engine_*` | Engine glow and trail attachment points |
| `Hardpoint_*` | Where the enemy's weapons fire from |

Details of how hitbox shapes are declared (in the scene or in enemy data) are added with the first enemies in M2.

The turret model holds the pivots, the view anchor and the mounts; each weapon model holds its own muzzles and ejection ports. A model with missing sockets still works: the game logs a warning and uses default positions.

## First-person view and lights

The turret and guns are drawn by a second camera with its own field of view (`camera.viewmodel_fov_deg` in `turret.json`) and laid over the world, so they never clip into it. They live on render layer 2 ("viewmodel"). **A light only reaches them if its Layers property includes layer 2**, so suns and explosion lights use layers 1 + 2.

## Placeholder models

`tools/build_placeholder_models.gd` builds the current placeholder `.glb` files from primitives. Re-run it after editing, then re-import:

```powershell
.\tools\godot.ps1 --headless --script res://tools/build_placeholder_models.gd
.\tools\godot.ps1 --headless --import
```

## Mod overrides (not built yet)

`AssetResolver.add_override_root()` is the hook for a future `mods/` folder next to the executable: a file at the same relative path under an override root wins over the built-in one. Runtime loading of external glTF and images is on the roadmap.

## Placeholder audio

`tools/build_placeholder_audio.py` writes every sound in `assets/audio/` (16-bit mono WAV). Asset ids follow the file names: `weapon_laser.wav` is `audio.weapon.laser`. Loops (`enemy_engine*`, `music_ambient`) are generated with a whole number of cycles so they repeat without a click; the game switches looping on when it loads them. See `docs/DATA_FORMAT.md` (config/audio.json) for where each sound is used.
