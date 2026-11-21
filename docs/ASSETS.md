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
| `Muzzle_0`, `Muzzle_1`, ... | Barrel ends; shots, tracers and muzzle flashes start here, −Z points out of the barrel |
| `Eject_0`, ... | Shell ejection ports for kinetic weapons, −Z is the ejection direction |

### Enemy models

| Node | Purpose |
|---|---|
| `Hitbox_*` | Position and scale markers for simple collision shapes (the render mesh is never used for hits) |
| `WeakPoint_*` | Destructible subsystems (shield generators, turrets, hangar bays, engines) |
| `Engine_*` | Engine glow and trail attachment points |
| `Hardpoint_*` | Where the enemy's weapons fire from |

Details of how hitbox shapes are declared (in the scene or in enemy data) are added with the first enemies in M2.

## Mod overrides (not built yet)

`AssetResolver.add_override_root()` is the hook for a future `mods/` folder next to the executable: a file at the same relative path under an override root wins over the built-in one. Runtime loading of external glTF and images is on the roadmap.
