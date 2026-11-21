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
- `collections`: a directory with one JSON file per entry. An optional `file_pattern` (default `*.json`) limits which files belong to it, e.g. `stage_*.json`. Every entry needs a unique id (`id_field`, default `"id"`), which should match the file name. Code reads them with `GameData.loader.get_entry("weapons", "pulse_laser")`.

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
| `aim.edge_min_input_scale` | Input scale right at a limit (1 = no resistance) |
| `aim.smoothing_default_s` | Default turret weight (time constant in seconds, 0 = none) |
| `aim.degrees_per_mouse_count` | Degrees turned per mouse count at sensitivity 1.0 |
| `model` | Asset ID of the turret model |
| `default_loadout.primary / alternate` | Weapon ids equipped at the start |
| `camera.screen_shake_max_deg` | Largest screen shake angle |
| `hull.max` | Base hull points |
| `camera.fov_horizontal_deg_at_16_9` | Default horizontal FOV at 16:9; wider screens see more |
| `camera.viewmodel_fov_deg` | Vertical FOV used to draw the first-person turret and guns |

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

## config/combat.json

Global damage rules.

| Field | Meaning |
|---|---|
| `shield_damage_multipliers.energy / kinetic / explosive` | Damage multiplier of each type against a target's shield |
| `armour_min_damage_fraction` | Share of a hit that always gets through armour |
| `splash_edge_damage_fraction` | Splash damage at the edge of an explosion (1.0 at the centre) |
| `hitbox_assist.min_angular_radius_deg` | Far targets never look smaller than this to the guns (degrees, seen from the turret). 0 turns the assist off |
| `hitbox_assist.max_scale` | The assist never grows a hitbox beyond this many times its real radius |

How a hit is resolved: the shield absorbs first (with the multiplier; if it breaks, the unused share continues). Then the target's `armour` minus the weapon's `armour_pierce` is subtracted as a flat amount. Then the target's resistance to that damage type is applied.

## config/input.json

Default bindings. Each action has a `display_name` and a list of `events`; an event is either `{ "key": "Escape" }` (Godot key name) or `{ "mouse_button": "left" }` (`left`, `right`, `middle`, `wheel_up`, `wheel_down`, `extra1`, `extra2`). An empty list means unbound.

## config/test_range.json

The practice targets of the test range. `model` is an asset ID, `respawn_s` the respawn time. Each entry of `dummies` has `yaw_deg`, `pitch_deg`, `distance_m` (position as seen from the turret), `radius_m`, `hp`, and optionally `armour`, `shield`, `shield_regen_per_s`, `shield_regen_delay_s`.

## weapons/*.json

One file per weapon. To add a weapon that uses an existing archetype, add a file here (and a model entry in the asset manifest); no code is needed.

```json
{
  "id": "pulse_laser",
  "display_name": "Pulse Laser Mk I",
  "archetype": "hitscan_pulse",
  "damage_type": "energy",
  "allowed_slots": ["primary"],
  "uses_power": true,
  "ammo_per_stage": 0,
  "damage": 9.0,
  "fire_rate": 8.0,
  "range_m": 6000.0,
  "armour_pierce": 0.0,
  "spread_deg": 0.04,
  "heat": { "per_shot": 0.028, "cooling_per_s": 0.3, "cooling_delay_s": 0.3, "overheat_unlock": 0.35 },
  "feel": { "recoil_pitch_deg": 0.1, "recoil_kick_m": 0.05, "recoil_recover_per_s": 16.0, "shake": 0.05 },
  "visuals": { "model": "model.weapon.pulse_laser", "crosshair": "cross", "tracer_color": [0.35, 0.9, 1.0], "tracer_width_m": 0.12, "tracer_life_s": 0.07, "impact_radius_m": 2.5 }
}
```

| Field | Meaning |
|---|---|
| `archetype` | `hitscan_pulse`, `beam`, `projectile`, `airburst`, `charge_pierce`, `spinup`, `homing`, `area_pulse`. Implemented so far: `hitscan_pulse`, `homing` (the validator warns about the others) |
| `damage_type` | `energy`, `kinetic` or `explosive` |
| `allowed_slots` | `primary`, `alternate` or both |
| `uses_power` | Whether the power split scales this weapon. Missiles use `false` |
| `ammo_per_stage` | Rounds per stage, refilled between stages. 0 = unlimited |
| `damage`, `fire_rate`, `range_m`, `armour_pierce`, `spread_deg` | Per shot damage, shots per second, maximum range, armour ignored, random cone half-angle |
| `heat.per_shot` | Heat added per shot (the meter runs 0 to 1; 1 = overheat) |
| `heat.cooling_per_s`, `heat.cooling_delay_s` | Cooling rate, and how long after the last shot cooling starts |
| `heat.overheat_unlock` | An overheated weapon works again once heat falls to this |
| `feel.recoil_pitch_deg`, `feel.recoil_kick_m`, `feel.recoil_recover_per_s`, `feel.shake` | View kick, gun model kick-back, recovery speed, screen shake (0 to 1) per shot |
| `visuals.model`, `visuals.projectile_model` | Asset IDs |
| `visuals.crosshair` | `cross`, `dot` or `circle` |
| `visuals.tracer_color`, `tracer_width_m`, `tracer_life_s`, `impact_radius_m` | Look of the shot and its impact |
| `audio.fire` | Asset ID of the firing sound (optional) |

Homing weapons add a `homing` block:

| Field | Meaning |
|---|---|
| `salvo_size`, `reload_s`, `launch_interval_s` | Missiles per salvo, reload time after a salvo, delay between missiles |
| `lock_time_s`, `lock_cone_deg` | Time to gain each lock, and how close to the crosshair a target must be |
| `launch_speed_mps`, `speed_mps`, `acceleration_mps2` | Speed leaving the pod, top speed, acceleration |
| `turn_rate_deg_s`, `arm_delay_s` | Steering limit, and the delay before steering starts |
| `lifetime_s`, `proximity_fuse_m`, `splash_radius_m` | Self-destruct time, detonation distance from the target's surface, blast radius |

## enemies/*.json

One file per enemy type. A new enemy that combines existing behaviour modules and attack types needs only a file here, a model in the asset manifest, and a mention in a stage.

| Field | Meaning |
|---|---|
| `id`, `display_name` | Identifier (matches the file name) and name shown to the player |
| `model`, `model_scale` | Asset ID of the model and an optional scale |
| `hitbox_radius_m` | Radius of the spherical hit shape (deliberately larger than small models) |
| `hp`, `armour`, `shield`, `shield_regen_per_s`, `shield_regen_delay_s` | Health values, see config/combat.json for how hits are resolved |
| `resistances.energy / kinetic / explosive` | Share of hull damage of that type that is ignored (0 to 1) |
| `speed_mps`, `turn_rate_deg_s` | Flight speed and how fast it can change direction |
| `behaviours` | List of behaviour ids from `behaviours/` |
| `attacks` | List of attacks, see below |
| `credit_bounty` | Credits for destroying it |
| `threat_cost` | What it costs the wave director. 0 = never bought automatically (bosses) |
| `first_stage` | First stage the director may use it in |
| `group_size` | `[min, max]` members when the director buys a group |
| `spawn.pitch_deg`, `spawn.distance_m` | Optional `[min, max]` spawn elevation and distance for this type |
| `death_effect.radius_m`, `death_effect.color` | Size and colour of its explosion |

Attack fields: `id`, `type`, `damage`, `count` (shots or bombs per attack), `interval_s` (between them), `cooldown_s`, `range_m`, `color`. Types:

- `collision`: damage on ramming (used by `approach_kamikaze`).
- `hitscan_burst`: instant shots at the turret (used by `strafe`).
- `guided_bomb`: releases shootable projectiles (used by `level_pass`). Needs a `projectile` block: `model`, `hp`, `hitbox_radius_m`, `speed_mps`, `max_speed_mps`, `acceleration_mps2`, `blast_radius_m`.

## behaviours/*.json

A behaviour is a module plus its parameters, so the same module can be tuned differently for different enemies.

```json
{ "id": "swarm_weave", "module": "approach_kamikaze", "params": { "weave_amplitude_m": 14.0, "weave_period_s": 2.4, "weave_fade_distance_m": 220.0, "impact_distance_m": 7.0 } }
```

| Module | What it does | Parameters |
|---|---|---|
| `approach_kamikaze` | Flies at the turret while weaving, then rams it | `weave_amplitude_m`, `weave_period_s`, `weave_fade_distance_m`, `impact_distance_m` |
| `strafe` | Attack runs: dive, fire, bank away to a point in the forward arc, return | `break_distance_m`, `retreat_yaw_deg`, `retreat_pitch_deg`, `retreat_distance_m` (each `[min, max]`), `retreat_reached_m`, `retreat_timeout_s` |
| `level_pass` | Level flight over the turret, releases bombs in range, then circles round for a new pass | `exit_distance_m`, `repass_delay_s` |

## stages/stage_NN.json

Authored stages, numbered from 1 without gaps (`stage_01.json`, ...). Later stages are generated from `director.json`.

```json
{
  "id": "stage_03",
  "stage": 3,
  "display_name": "Bomb Run",
  "briefing": "Bombers at high altitude. Shoot the bombs down before they land.",
  "time_of_day": "dusk",
  "par_time_s": 120.0,
  "spawn_yaw_deg": [-70.0, 70.0],
  "waves": [
    { "delay_s": 1.0, "groups": [ { "enemy": "bomber", "count": 1, "spawn": { "yaw_deg": [-10.0, 10.0] } } ] },
    { "delay_s": 5.0, "budget_share": 0.4, "enemies": ["drone_swarmer", "interceptor"] }
  ]
}
```

- `spawn_yaw_deg`: the part of the arc enemies come from in this stage.
- A wave may have explicit `groups` (`enemy`, `count`, optional `spawn` with `yaw_deg`, `pitch_deg`, `distance_m` ranges), a `budget_share`, or both.
- `budget_share` is a share of the stage's threat budget, which the director spends on the types in `enemies` (or on every type unlocked at that stage if the list is empty).
- `delay_s`: pause before the wave starts. The next wave starts when most of the current one is destroyed or after a timeout (see director).
- `display_name` and `briefing` are the stage's text; story can be added here later.

## stages/director.json

| Field | Meaning |
|---|---|
| `base_budget`, `growth` | `threat_budget(stage) = base_budget × growth^(stage − 1)`, times the difficulty's `threat_budget_mult` |
| `intro_s` | Length of the stage intro banner |
| `spawn_interval_s` | Time between two spawns of a wave |
| `group_spread_m` | How far group members are scattered around the group's centre |
| `min_spawn_altitude_m` | Nothing spawns below this height |
| `wave_clear_fraction` | The next wave starts when this share (or less) of the current wave is left |
| `wave_timeout_s` | ...or this long after the wave finished spawning |
| `default_spawn` | Spawn ranges used when neither the group, the stage nor the enemy sets them |
| `procedural.*` | Rules for generated stages: number of waves, delay, how the yaw arc widens, par time |

## Planned formats

Added in the milestone that first uses them:

- `shields/*.json` (M3)
- `enemies/*.json`, `behaviours/*.json`, `stages/stage_NN.json`, `stages/director.json` (M2)
- `techtree/tree.json` with generic modifiers and the effect registry (M4)
