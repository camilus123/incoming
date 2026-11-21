# Data formats

All balance and content lives in `data/` as JSON. This file documents every format. It grows with each milestone; sections marked *(planned)* are not loaded yet.

## How data is loaded

1. `data/schemas/index.json` lists every data file and the schema that checks it.
2. `DataLoader` reads each file, checks it with `DataSchema` and stores a cleaned copy.
3. `DataValidator` runs cross-file checks (references, consistency).
4. Problems are collected in a `DataReport` as `ERROR file [field]: problem`.

The game never crashes on bad data:

- A **config** file that is missing or unreadable falls back to the defaults in its schema. A single bad field falls back to that field's default.
- A **collection** entry (one file per weapon, enemy, ...) with any error is skipped.
- Unknown fields are reported as warnings (usually a typo) and ignored.
- Any key starting with `_` (for example `"_comment"`) is ignored, so you can leave notes in the files.

Check your edits with `.\tools\validate_data.ps1`. In a debug build, press **F5** in the running game to reload all data.

## index.json

```json
{
  "configs": [
    { "name": "power", "file": "config/power.json", "schema": "schemas/power.schema.json" }
  ],
  "collections": [
    { "category": "weapons", "directory": "weapons", "schema": "schemas/weapon.schema.json", "id_field": "id" }
  ]
}
```

- `configs`: single files holding one object. Code reads them with `GameData.loader.get_config("power")`.
- `collections`: a directory with one JSON file per entry. Every entry needs a unique id (`id_field`, default `"id"`), which should match the file name. Code reads them with `GameData.loader.get_entry("weapons", "pulse_laser")`.

Paths are relative to `data/`.

## Schema format

A schema describes one value:

| Key | Applies to | Meaning |
|---|---|---|
| `type` | all | `string`, `number`, `int`, `bool`, `array`, `object`, `dict` or `any` |
| `required` | object fields | The field must be present (error if missing) |
| `default` | object fields | Value used when the field is missing or invalid |
| `min`, `max` | `number`, `int` | Inclusive range |
| `enum` | `string` | List of allowed values |
| `non_empty` | `string` | Must not be `""` |
| `items` | `array` | Schema for each item. Invalid items are dropped |
| `min_items` | `array` | Minimum number of valid items |
| `fields` | `object` | Map of field name to schema (fixed set of keys) |
| `allow_unknown` | `object` | Keep unknown fields instead of warning |
| `values` | `dict` | Schema for every value (free set of keys, e.g. presets by name) |
| `required_keys` | `dict` | Keys that must exist |

Example:

```json
{
  "type": "object",
  "fields": {
    "id": { "type": "string", "required": true, "non_empty": true },
    "hp": { "type": "number", "min": 1, "default": 50 },
    "damage_type": { "type": "string", "enum": ["energy", "kinetic", "explosive"], "default": "energy" },
    "behaviours": { "type": "array", "items": { "type": "string" }, "default": [] }
  }
}
```

## config/power.json

Power split between shields and weapons. `weapon_share = 1 − shield_share`.

```json
{
  "shield_share": { "default": 0.5, "step": 0.1, "min": 0.0, "max": 1.0 },
  "shield_recharge_multiplier": { "at_zero_share": 0.0, "at_full_share": 2.0 },
  "weapon_output_multiplier": { "at_zero_share": 0.5, "at_full_share": 1.5 }
}
```

- `shield_share`: starting value, wheel step and limits.
- `shield_recharge_multiplier`: linear from `at_zero_share` (shield share 0) to `at_full_share` (shield share 1).
- `weapon_output_multiplier`: linear from `at_zero_share` (weapon share 0) to `at_full_share` (weapon share 1).

## config/economy.json

| Field | Meaning |
|---|---|
| `starting_credits` | Credits before stage 1 |
| `stage_base.base`, `stage_base.per_stage` | Stage reward = `base + per_stage × stage` |
| `accuracy_bonus_per_percent` | Credits per percent of accuracy |
| `hull_bonus_per_percent` | Credits per percent of remaining hull |
| `no_shield_break_bonus` | Flat bonus if shields never fully depleted |
| `speed_bonus.max` | Largest speed bonus |
| `speed_bonus.full_bonus_ratio` | Full bonus when clear time ≤ par × this |
| `speed_bonus.zero_bonus_ratio` | No bonus when clear time ≥ par × this (linear in between) |
| `intercept_bonus` | Credits per enemy missile, bomb or pod shot down |
| `respec_refund_ratio` | Share of a node's cost refunded on respec (0 to 1) |
| `hull_repair.cost_per_point` | Credits per hull point repaired |

## config/difficulty.json

```json
{
  "default": "normal",
  "levels": {
    "hard": {
      "display_name": "Hard",
      "enemy_hp_mult": 1.25,
      "enemy_damage_mult": 1.3,
      "spawn_rate_mult": 1.2,
      "threat_budget_mult": 1.2,
      "reward_mult": 1.1
    }
  }
}
```

`default` must name one of the `levels`. Add a level by adding a key.

## config/turret.json

| Field | Meaning |
|---|---|
| `aim.yaw_min_deg`, `aim.yaw_max_deg` | Yaw limits in degrees, 0 = straight ahead |
| `aim.pitch_min_deg`, `aim.pitch_max_deg` | Pitch limits in degrees, 0 = horizon |
| `aim.edge_soft_zone_deg` | Width of the soft-resistance zone before each limit |
| `aim.smoothing_default_s` | Default turret weight (time constant in seconds, 0 = none) |
| `hull.max` | Base hull points |
| `camera.fov_horizontal_deg_at_16_9` | Default horizontal FOV at 16:9; wider screens see more |
| `camera.viewmodel_fov_deg` | FOV used to draw the first-person gun model |

## config/graphics_presets.json

`default` names the preset used on first launch. `presets` must contain `low`, `medium`, `high` and `ultra`. Fields per preset:

| Field | Values |
|---|---|
| `display_name` | Text shown in settings |
| `render_scale` | 0.25 to 2.0 |
| `upscaler` | `none`, `fsr1`, `fsr2` |
| `antialiasing` | `none`, `fxaa`, `taa` |
| `shadows` | `off`, `low`, `medium`, `high`, `ultra` |
| `gi` | `off`, `ssil`, `sdfgi` |
| `ssao`, `ssr`, `volumetric_fog`, `glow` | `true` / `false` |
| `particle_density` | Multiplier for particle counts |
| `effect_view_distance_m` | Effects beyond this distance are not drawn |
| `max_active_particle_systems`, `max_decals` | Caps |

## assets/asset_manifest.json

Maps asset IDs to files. See `ASSETS.md`.

```json
{
  "assets": {
    "model.weapon.pulse_laser": { "path": "res://assets/models/weapons/pulse_laser.glb", "type": "model" },
    "audio.weapon.pulse_laser.fire": { "path": "res://assets/audio/weapons/pulse_laser_fire.wav", "type": "audio", "fallback": "audio.generic.shot" }
  }
}
```

- `path`: the file. The validator reports an error if it does not exist.
- `type`: `model`, `scene`, `texture`, `material`, `audio`, `font` or `vfx`.
- `fallback` (optional): another asset ID used if this one cannot be loaded.

## Planned formats

Added in the milestone that first uses them:

- `weapons/*.json`, `shields/*.json` (M1, M3)
- `enemies/*.json`, `behaviours/*.json`, `stages/stage_NN.json`, `stages/director.json` (M2)
- `techtree/tree.json` with generic modifiers and the effect registry (M4)
