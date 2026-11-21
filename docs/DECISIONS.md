# Decisions

Design and technical decisions that are not in the original build spec, newest section last. "Marko" entries were decided by the developer; "Claude" entries are small, reversible calls made during development.

## 2026-11-21: Section 0 answers (Marko)

| # | Topic | Decision |
|---|---|---|
| 1 | Engine | Godot 4.7.2-stable, standard build, kept outside the repo. |
| 2 | Language | Statically typed GDScript. No C#. |
| 3 | Repo | Work in a clone of `camilus123/incoming`, on top of its initial commit. |
| 4 | Git identity | Repo-local: `Marko` with the GitHub noreply address. |
| 5 | Git LFS | Used for `*.glb, *.png, *.jpg, *.exr, *.hdr, *.wav, *.ogg`. Placeholders stay small. |
| 6 | Tests | GUT (MIT) in `addons/gut`, run headless. |
| 7 | Running | Claude runs Godot headless for validation/tests and windowed for benchmarks/screenshots. Feel checks are done by Marko. |
| 8 | Exclusive branches | Only shields (Bastion vs Flicker). All weapon families can be owned together. |
| 9 | Respec | Allowed in the shop. **Refund is 100 % for now** to make testing easier (`economy.json: respec_refund_ratio`); the design value is 75 %. A node cannot be refunded while a purchased node depends on it. Refunding the first shield branch node reopens the other branch. |
| 10 | Endless | Procedural stages after stage 10, scaled boss every 5th stage. |
| 11 | Game over | Retry returns to the shop autosave before the failed stage. No permadeath. |
| 12 | Armour | Flat per-hit damage reduction against **all** damage types. Each weapon has `armour_pierce` in data. Kinetic weapons get high pierce, fast low-damage energy shots are weak against armour. (The spec's "reduction vs kinetic" contradicted "kinetic is strong vs armour".) |
| 13 | Enemy shields | Absorb all damage before HP. Multipliers vs shields: energy 2×, kinetic 0.5×, explosive 1× (configurable). **Enemy shields regenerate** if the enemy is not killed (rate and delay in enemy data). |
| 14 | Mk II / Mk III costs | Where the spec gives none: Mk II = 40 %, Mk III = 80 % of the weapon's unlock cost, rounded to the nearest 50. |
| 15 | Missiles and power | **Missiles do not use reactor power.** They have a limited ammo stock that runs out during a stage and is refilled only after the stage. The power split does not affect them. See the open question below for non-missile alternates. |
| 16 | Boss stages | Authored as the boss plus escorts bought with 50 % of the stage's normal threat budget. |
| 17 | Cross-branch prerequisites | Allowed (e.g. Rail Lance requires Coilgun), drawn as a link between branches. |
| 18 | Spelling | British spelling in data keys and docs (`armour`, `behaviours`). English only. |
| 19 | Schemas | Own small schema format (see `DATA_FORMAT.md`), not full JSON Schema. |
| 20 | Placeholder art | Script-built primitive models exported as `.glb`, plus a few CC0 textures and a sky. **Also keep `docs/ART_BRIEF.md`** describing what the final models and textures should look like. |
| 21 | Narrative | No story for now: a short setting paragraph and one-line stage briefings, stored in data **so story can be added later** without code changes. |
| 22 | Audio | Generated placeholder SFX plus a few CC0 ones. Alerts are a tone plus HUD text. One CC0 ambient music track in M8. |
| 23 | Milestones | Stop and report after every milestone; wait for go-ahead. |
| 24 | Git flow | Commit on `milestone/...` branches, push the branch at the milestone report, merge to `main` only after Marko approves. No pull requests unless asked. |
| 25 | Low preset | Cannot be measured on GTX 1660 class hardware; reported as an unverified estimate. |

### Open question from answer 15

The answer covers missiles. For the other alternates the working assumption (to be confirmed before M5, when they are built) is:

- Homing weapons (Micro-Missile, Swarm Missiles, Seeker Torpedo): per-stage ammo, no power scaling.
- Flak Barrage (kinetic/explosive shells): per-stage ammo as well.
- EMP Burst, Arc Projector, Rail Lance, Singularity Charge: reactor-powered, scale with the weapon share like energy weapons, no ammo.

The Micro-Missile Pod keeps its 6 s reload between salvos; the ammo stock limits the number of salvos per stage. All of this is per-weapon data (`ammo_per_stage`, `uses_power`).

## 2026-11-21: M0 technical decisions (Claude)

- **Physics engine: Jolt** (`project.godot`). It is the default for new 3D projects in current Godot and faster for many moving bodies.
- **UI stretch: `canvas_items` + `expand`**, base 1920×1080. UI scales with resolution and gains width on 21:9 instead of stretching.
- **Schemas live in `data/schemas/`** and `data/schemas/index.json` lists every data file, so adding a new data file or field is a data change, not a code change.
- **Bad data policy:** a broken config file falls back to the defaults in its schema; a broken collection entry (weapon, enemy, ...) is skipped; unknown fields are warnings. Keys starting with `_` (e.g. `_comment`) are ignored.
- **Hull default 200** (`turret.json`). The spec gives no hull value; this is a first guess next to the 100-point starting shield.
- **Speed bonus formula:** full bonus (300) at clear time ≤ 0.6 × par, zero at ≥ 1.2 × par, linear in between (`economy.json`).
- **Hull repair cost:** 2 credits per hull point (`economy.json`).
- **Wrapper scripts are PowerShell** and find Godot through `GODOT_BIN` or the PATH, so no machine-specific path is committed.

## 2026-11-21: confirmations after M0 (Marko)

- Alternate weapons: Flak Barrage uses per-stage ammo like the missiles; EMP Burst, Arc Projector, Rail Lance and Singularity Charge use reactor power. Confirmed.
- Hull 200 is fine as a start and may change with balance.

## 2026-11-21: M1 technical decisions (Claude)

- **Viewmodel:** the turret and guns are drawn by a second camera into a transparent SubViewport laid over the world (own FOV, no clipping). Lights must include render layer 2 to light them. Shots are traced from the sighting position so they land exactly under the crosshair; tracers are drawn from the muzzle as it appears on screen.
- **Aim feel:** the mouse moves the aim directly and the camera uses that exact aim. Only the visible gun model is smoothed (30 ms time constant by default, 0 = off), so weight never costs responsiveness. Input uses unaccumulated, unscaled mouse counts.
- **Arc edges:** inside the last 4° before a limit, input towards the limit is scaled down to 35 %, then clamped. The HUD shows a yaw/pitch arc map and amber brackets near a limit.
- **FOV:** 90° horizontal is defined at 16:9 and converted to a fixed vertical FOV, so 21:9 sees more to the sides (Hor+).
- **Micro-Missile Pod:** hold RMB to collect up to 4 locks (0.3 s each, within 7° of the crosshair), release to launch; without locks the missiles fly straight. 32 missiles per stage (8 salvos), first guess.
- **Recoil is visual only:** the view kick and gun kick-back do not move the aim.
- **Input bindings are data** (`config/input.json`); `project.godot` contains no actions. The player's rebinds (M8) will be stored on top.
- **Weapon timing runs per rendered frame**, not on the 60 Hz physics tick, so fire and missiles stay smooth at 240 Hz.
- **Test range:** the M1 scene is `scenes/main/test_range.tscn` with dummies from `config/test_range.json`. It stays as a debug scene after M2 adds real stages.
- **Automated demo** (`tools/run_demo.ps1`): drives the turret without a player, prints fps and saves screenshots. It is a stop-gap for the M7 benchmark mode.
- **No audio yet.** Weapon files have an `audio` block, but sounds arrive with the M8 audio pass.
