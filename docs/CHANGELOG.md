# Changelog

Updated at every merge to `main`.

## Version 1.0 (2026-11-28)

First release: milestones M0 to M8 as listed below. Tagged `v1.0`; the Windows build is attached to the GitHub release.

## M8: Polish (2026-11-22)

- Sound: six buses (Master, Music, SFX, Weapons, UI, Alerts), 37 generated placeholder sounds, a fire sound per weapon family, sized explosions and hits placed in the world, engine loops with Doppler shift on larger enemies, alert tones (shields down and up, hull critical, overheat, incoming ordnance), interface clicks and an ambient music loop. All named by asset id in data.
- Main menu: continue, new run, difficulty (Easy, Normal, Hard), settings, quit.
- Pause menu: resume, settings, restart stage, main menu, quit.
- Settings: mouse sensitivity, invert Y, rebinding of every action (with wheel swap and reset), graphics preset, renderer (Vulkan or DirectX 12, after a restart), fullscreen, V-Sync, frame rate limit, field of view, lens effects, six volume sliders, screen shake and turret weight.
- Hold Tab for stage stats and what is in the air.
- Debug menu (F4, debug builds): credits, skip stage, spawn an enemy, god mode, show hit shapes, stats overlay.
- Windows export preset and `tools\export_windows.ps1`.
- 17 new unit tests (151 in total).
- After the play test: the ambient music was too low and too quiet to hear; it is now an audible four-chord pad.

## M7: Performance pass (2026-11-22)

- Benchmark mode: `tools\run_benchmark.ps1` or `--benchmark` plays a scripted fight with about 115 enemies at once and writes average fps, median, 1 % lows, a per-second timeline and every frame time to a JSON file.
- Explosions right at the camera no longer draw fire and smoke over the whole screen (1 % low on Ultra in the benchmark: 52 to 163 fps from this alone).
- Swarm drones are drawn as one MultiMesh and advanced by the enemy manager in one loop.
- Destroyed swarm drones and enemy projectiles are pooled and reused.
- Fuses, splash damage, lock-on and beam chains read a target registry instead of asking the scene tree for a group every call.
- The one long frame per stage (30 to 35 ms) is gone; an idle shield is no longer drawn.
- Result on the reference PC, benchmark at 3440×1440: Ultra 257 fps average and 204 fps 1 % low; High 367 and 237.
- 10 new unit tests (134 in total).

## M6: Graphics pass (2026-11-22)

- A frontier world built from data (`config/environments.json`): physical sky with day, dusk and night per stage, sun or moonlight with cascaded shadows, distance and volumetric fog, generated dunes and mountains, a ringed gas giant, a moon and a star field.
- Graphics presets Low, Medium, High and Ultra now do something: render scale with FSR 1 or FSR 2, TAA or FXAA, shadow quality, SSAO, SSIL or SDFGI, SSR, volumetric fog, glow, particle density, effect distance and pool sizes. `--preset=<id>` or F3 (debug) switches.
- Particle effects: explosions with fire, smoke and debris, impact sparks, shell casings from kinetic guns, barrels that glow as they heat up, fire trails behind drop pods.
- Lens effects: chromatic aberration on hull hits and near explosions, lens dirt on big blasts, a refraction ripple when the shield is hit. A preset switch and a setting turn them off.
- HUD: backing panels and text shadows for readability against a bright sky, segmented shield and hull bars, a pulsing low-hull warning, a tidier stage strip. The developer read-out is hidden until F1.
- Tracers, flashes and bolts are drawn as three MultiMesh pools instead of about 250 separate meshes.
- `run_demo.ps1` passes extra options on to the game; new demo options `--demo-frame-log`, `--time=<id>`.
- The Plasma Cannon bolt is twice as large.
- 9 new unit tests (124 in total).
- After review: the shield is invisible until hit and turns from blue to orange-red as it drains; all presets use FSR 2 (native, quality, balanced, performance) and Ultra is the default; lens effects toned down.

## M5: Content pass (2026-11-22)

- Six new weapon archetypes: `projectile`, `airburst`, `beam`, `spinup`, `charge_pierce`, `area_pulse`; homing gained auto-distributing salvos and a player-steered torpedo.
- Changes after the M5 play test: slow launchers (Singularity Charge) show a reload bar and a "READY" flash; the Seeker Torpedo homes on the target under the crosshair and is faster and more agile; the Dreadnought is twice as large and cruises a loop in front of the turret instead of hovering (the carrier too); all projectile weapons fly about twice as fast, so they need much less lead; proximity fuses are checked along the whole flight step.
- All 20 weapons of Section 4 as data: Beam Laser, Particle Lance, Plasma Repeater and Cannon, Chain Gun, Rotary Cannon, Autocannon, Twin Autocannon, Coilgun, Railgun, Hyper-Rail, Swarm Missiles, Seeker Torpedo, Flak Barrage, EMP Burst, Arc Projector, Rail Lance, Singularity Charge. Every tech tree node is now live.
- Pooled projectile system with swept collision, proximity fuses, splash, piercing, lingering trails and gravity wells.
- All 9 enemies of Section 5: Missile Boat, Orbital Drop Pod, Shield Frigate, Gunship, Carrier and the Dreadnought boss join the first three.
- Enemy systems: weak points and weak point groups, multiple hit shapes, behaviour modules `hover_shoot`, `orbit_drop`, `spawn_children`, `shield_allies`, `phases`, flares, ally shields.
- Stages 4 to 10 authored, with boss stages at 5 and 10. Endless mode scales enemies and brings a tougher boss every fifth stage.
- HUD: lead indicators (Targeting Computer), weak point markers, charge and spin-up ring.
- Armour acts per second on beams and trails; intercept bonus capped per stage.
- Placeholder models for every weapon, enemy and projectile.
- 115 tests, including integration tests that fire every weapon and run every enemy.

## M4: Economy, shop and tech tree (2026-11-22)

- Full loop: armoury, stage, itemised rewards, armoury.
- Tech tree with all 79 nodes of Section 4 in `data/techtree/tree.json`: prerequisites (`all_of`, `any_of`), the Bastion/Flicker exclusive group, positions and colours.
- Generic modifiers (`set`, `add`, `mul` on shield, weapon, turret, power and HUD stats) and a special-effect registry: Hardened Matrix, Aegis Bulwark, Reflex Field, Phase Pulse.
- Armoury screen: zoomable, pannable node graph, tooltips with before/after values, buy and refund (respec), loadout pickers, hull repair, next-stage preview.
- Reward calculator with the spec's formulas and a breakdown screen.
- Run state (`GameState`) with autosave to `user://saves/run.json`, save versioning and a migration hook; retry from the last save after game over.
- Shields: Bastion keeps the dome, Flicker switches to the conformal shell. Conformal shell floats off the hull.
- Upgrade-driven HUD features: enemy health bars, ordnance warnings.
- Enemy attacks have damage types; turret resistances; enemies can be staggered.
- 101 unit tests, including one that adds a new upgrade from JSON alone.

## M3: Shields and power (2026-11-21)

- Shield system: capacity, recharge rate and delay from `data/shields/`; shields absorb damage before the hull.
- Power split on the mouse wheel (middle click resets): shield recharge 0× to 2×, weapon output 0.5× to 1.5×, all from `power.json`.
- Energy weapons scale damage with power; kinetic weapons scale fire rate and cooling; missiles are unaffected.
- Shield dome effect with hex lattice, impact ripples and break/restore flashes.
- HUD: shield bar, power gauge, "SHIELDS DOWN" message, live power numbers in the debug overlay.
- Distance-assisted hitboxes and easier M2 enemy values (from M2 feedback); numpad Enter confirms.
- 72 unit tests.

## M2: Enemies and stages (2026-11-21)

- Enemy framework: `Enemy` on top of `CombatTarget`, data-driven stats, behaviours and attacks, `EnemyManager`.
- Behaviour modules `approach_kamikaze`, `strafe` and `level_pass`.
- Swarm Drone, Interceptor and Bomber with shootable guided bombs.
- `WaveDirector` with the threat budget formula, budget-share and explicit-group waves, generated stages after the authored ones.
- `StageManager`: intro, waves, stage complete summary, game over with retry. Stages 1 to 3 authored in data.
- Turret hull damage and destruction; difficulty multipliers applied to enemies.
- HUD: stage, wave and hostile count, threat diamonds and off-screen arrows, damage flash.
- Shared environment scene; the test range is now a separate debug scene.
- Fixes: pause now really pauses; explosions near the camera no longer white out the screen.
- 54 unit tests.

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
