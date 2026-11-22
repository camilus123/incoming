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

## 2026-11-21: M2 decisions (Claude)

- **Armour floor raised to 30 %** (`combat.json: armour_min_damage_fraction`, was 10 %). With the flat-armour rule the starting Pulse Laser (9 damage) did under 1 damage per shot to a Bomber (armour 8), which made stage 3 a four-minute grind with the starting loadout. Now armour never blocks more than 70 % of a hit. Kinetic weapons with armour pierce are still clearly better against armour.
- **Hitboxes are larger than the models** for small enemies (drone 3 m, bomb 2.5 m radius) and every threat gets a small HUD diamond, because a 4 m drone at 1 km is only a few pixels at 1440p.
- **Drones spawn at 900 to 1,500 m**, inside the spec's 300 to 4,000 m range, so the swarm is visible and reaches the turret in 13 to 21 s.
- **Bombs are guided**, not ballistic: they keep the bomber's velocity at release, then accelerate straight at the turret. A true ballistic drop from 600 m would take 11 s and miss a point target. They are shootable (25 hp).
- **Bombers and passes:** after flying over the turret a bomber leaves the fight for a few seconds and starts a new pass from the front, so it never attacks from outside the aim arc. It still has to be destroyed to finish the stage.
- **Interceptor lasers always hit** when fired (in range and pointing at the turret). The counter-play is killing or out-lasting them; this will be revisited when shields arrive in M3.
- **Enemy behaviours are data + modules:** `behaviours/*.json` picks a module and its parameters; attacks are data on the enemy. Modules so far: `approach_kamikaze`, `strafe`, `level_pass`.
- **Waves:** a wave is explicit groups and/or a share of the stage budget. The next wave starts when 25 % or less of the current one is left, or after 28 s.
- **Stages after the authored ones** are already generated from `director.json`, so play continues past stage 3. Proper endless tuning and bosses are M5.
- **Until the shop exists (M4)** the turret is fully repaired and re-armed at the start of every stage. Stage complete and game over screens use Enter and R; real menus come in M8.
- **Explosions that engulf the camera are not drawn** (back-face culling on the glow shader). Otherwise a drone ramming the turret whites out the whole screen. The red damage frame and shake carry that feedback instead.
- **Pause bug fixed:** in M1 the pause key showed "PAUSED" but nothing actually stopped.
- **Balance was checked with an aim-bot** (`tools/run_demo.ps1`), which finishes stages 1 to 3 with 140 to 185 of 200 hull. A human will lose more; numbers will be retuned once shields exist.

## 2026-11-21: M2 difficulty feedback (Marko)

Marko found M2 too hard and asked for bigger hitboxes, especially at range.

- **Distance-assisted hitboxes** (`combat.json: hitbox_assist`): every enemy and bomb keeps a minimum apparent hit radius of 0.55° as seen from the turret (about 13 px at 1440p), capped at 8× its real radius. Close up the real hitbox applies. The HUD diamond on each threat is drawn at exactly this size, so it shows where a shot counts.
- Also eased (Claude): drone weave 14 m to 9 m, interceptor burst cooldown 2.5 s to 3.5 s, bombers drop 2 bombs per pass instead of 3, and stage 3's third wave has one bomber instead of two.

## 2026-11-21: M3 decisions (Claude)

- **Power split effects by weapon type:** energy weapons scale damage (and bolt brightness); powered non-energy weapons (kinetic) scale fire rate and cooling; unpowered weapons (missiles) are unaffected. In M1/M2 the laser's cooling also followed the split; it no longer does, matching the spec.
- **Shield recharge = base rate × split multiplier**, after the shield's own delay. At 0 % shield share the multiplier is 0: the shield keeps its charge but does not refill. `ShieldState.min_recharge_multiplier` is the hook for Bastion IV.
- **Shield dome:** a hemisphere of 14 m radius around the turret, drawn additively and almost invisible at rest (the player looks through it all the time), with a hex lattice that ripples from the point of each hit and flashes when the shield breaks or returns. Its ripple loop only runs while hits are active, because a full-screen effect at 3440×1440 is not free.
- **Hits carry their origin** (`Turret.take_damage(amount, from_position)`) so ripples appear on the side the damage came from.
- **HUD:** shield bar above the hull bar, a vertical power gauge (weapons orange on top, shields blue below) that slides on each wheel step, "SHIELDS DOWN" message. The debug overlay shows the live recharge rate and weapon output.
- **No audio tick yet** for the wheel step; it arrives with the M8 audio pass.
- **Screen-space shield-impact distortion** (spec 3.2) is left for the M6 graphics pass; the dome ripple covers the feedback for now.
- **Numpad Enter** also confirms (Marko's request).

## 2026-11-21: shield styles (Marko)

Marko asked for two looks: one shield type as the dome, the other as a conformal shield just around the turret.

- **`visuals.style` in each shield file** picks the look: `dome` or `conformal`. Both implement `ShieldVisual`, so more styles can be added.
- **Conformal** is a generated shell around every mesh of the turret and guns (hex lattice, edge glow, a wave that runs round the turret from the side that was hit). Each mesh is grown outwards by `conformal_offset_m` (6 cm by default); vertices sharing a corner move together, so the shell floats off the hull without opening at hard edges. Because it is built from the real meshes it automatically fits any replacement model.
- **Proposed mapping for M4 (to confirm):** Basic Deflector and the Bastion branch use the dome (big, heavy shield); the Flicker branch uses the conformal skin (tight, fast shield).
- **Dome bug fixed:** the lattice was drawn on the ground when looking down, because the hemisphere mesh has a flat base and the wall reached the terrain. The base is now discarded and the dome fades out near the ground.

## 2026-11-21: shield style mapping (Marko, by go-ahead)

Basic Deflector and Bastion use the dome; Flicker uses the conformal shell (`flicker_1` sets `shield.visuals.style`).

## 2026-11-22: M4 decisions (Claude)

- **The shop is an overlay, not a separate scene.** The turret stays visible behind it and changes as you buy (new shield look at once). Loop: armoury, stage, rewards, armoury.
- **Run state lives in the `GameState` autoload**: credits, stage, purchased nodes, loadout, hull. It computes every upgraded stat on demand from base data plus the purchased modifiers; nothing stores upgraded numbers, so respec and hot reload cannot go out of sync.
- **Modifier stacking:** last `set` (or base) + all `add`s, × all `mul`s. Order-independent apart from which `set` is last.
- **Armoured Hull** is additive: each level adds 25 % of the base hull (`turret.hull.max_bonus`), so two levels give 300, not 312.5.
- **Shield Harmonics / Kinetic Dampers** reduce all incoming damage of that type before the shield takes it. Enemy attacks now carry a `damage_type` (interceptor laser: energy, drone ram: kinetic, bombs: explosive).
- **Weapons of later milestones:** the tree contains all of Section 4. Nodes whose weapon has no data yet are listed under `planned_weapons`, shown as "LATER BUILD" and cannot be bought. They become live automatically when M5 adds the weapon files.
- **Mk II / Mk III for weapons the spec does not detail:** Mk II = damage ×1.2, heat ×0.9; Mk III = damage ×1.2, fire rate ×1.1, heat ×0.9 (first guesses; archetype-specific bonuses come in M5). Pulse Laser and Micro-Missile have their own values.
- **Targeting Computer** currently gives enemy health bars; lead indicators arrive with projectile weapons in M5. **Threat Radar** gives off-screen arrows for bombs and an "INCOMING ORDNANCE" warning; without it bombs are only marked while on screen.
- **Hull repair:** 2 credits per point; if you cannot afford a full repair the button repairs what you can pay for.
- **Autosave** when the armoury opens. Game over, R: back to that save (the armoury before the lost stage). Enter: new run. The shop has a two-click "Start a new run".
- **Hull now carries over between stages** and is repaired only in the armoury. The shield and ammo are refilled each stage; the power split resets to 50/50.
- **Debug:** F2 in the armoury adds 1,000 credits (debug builds only). The rest of the debug menu from spec 14 is still to do.
- **Demo and debug starts never touch the save** (`--auto-demo`, `--stage=N`, the test range).

## 2026-11-22: dome lattice mapping (Marko)

Marko pointed out that looking up, the dome looked like a tunnel going up for ever. The hex lattice was mapped by longitude and latitude, which squeezes every cell into the pole. It now uses a stereographic projection centred overhead: cells are regular hexagons everywhere and only grow gently towards the ground, so the dome reads as a bubble around the turret.

## 2026-11-22: M5 decisions (Claude)

- **Weapon stats are first guesses** aimed at these sustained damage levels: starting weapons about 70 dps, first-tier unlocks 120 to 180, second tier 180 to 270, top tier higher but with a catch (heat, charge time, ammo). They need Marko's hands to tune.
- **Armour works per second on continuous damage.** A beam deals damage in 0.1 s ticks; with flat armour per hit a 70 dps beam would do almost nothing to any armoured target. Each tick now meets only its share of the armour (`DamageInfo.armour_factor`).
- **Weak points are their own targets.** They have their own hp (no armour by default), can be locked by missiles, and a shot whose line passes through one hits it even when the hull's hit shape surrounds it. Destroying them deals internal damage to the owner that ignores shields and armour, so going for weak points is the fast way through a capital ship.
- **Dreadnought:** two shield generators (both gone: no shield), four turrets (all gone: no turret guns), three engines (all gone: no beam sweep and a large hit to the hull). Phases at 66 % hull (missile walls) and 33 % (drone launches). It holds at about 2 km.
- **Carrier:** launches 6 drones every 10 s until all four hangar bays are destroyed.
- **Shield Frigate:** covers allies within 320 m with a 60-point regenerating shield; its projector is a weak point that ends the cover and its own shield.
- **Gunship flares:** each missile aimed at it has a 50 % chance to lose its lock.
- **Drop pods** fall from 3 to 4 km at 250 m/s and count as enemies (bounty, must be destroyed or they hit for 60).
- **Seeker Torpedo:** press to launch, hold to guide: it homes on the target nearest the crosshair (within `lock_cone_deg`, shown as a lock) or flies along the crosshair line if there is none; released, it keeps homing on its last target. (Changed after the M5 play test: pure manual steering was too hard to hit with.)
- **Swarm Missiles:** one press; 16 missiles spread over every target within 30° of the crosshair.
- **EMP Burst** strips shields of everything in 130 m and stuns enemies tagged `drone` for 4 s. It needs enemy shields or drones to be worth it.
- **Singularity Charge** pulls enemies under 1,000 hp; big ships only take the implosion.
- **Intercept bonus is capped** at 30 per stage: missile boats and the boss fire without end, and shooting their missiles down forever would be a credit farm.
- **Endless mode:** enemies gain 3 % hp and 2 % damage per stage past stage 10; every fifth stage has a Dreadnought with 1.5× the hull and 1.25× the damage of the previous one, and half the usual escort budget.
- **Generic Mk II / Mk III modifiers** apply to all weapons because every archetype reads `damage` and `heat.per_shot` (per second for beams).

## 2026-11-22: M5 balance notes (Claude)

Checked with the self-playing demo, which is only a rough guide (it never misses with instant-hit weapons and cannot use charge or slow projectile weapons well):

- Stages 1 to 9 clear from a normal run, and stage 5's Dreadnought falls to a 7,000-credit build.
- Stage 10 was cleared only with shield and hull upgrades. A weapons-only build loses: the Dreadnought, a Shield Frigate and interceptors together out-damage the basic 100-point shield. This is meant to reward mixed builds but needs a human verdict.
- First versions were much harsher and were toned down: the Dreadnought now only fires inside 2,400 m (it used to open fire the moment it appeared), its beam and turret damage were roughly halved, both boss stages have smaller escorts with longer gaps between waves, gunships fire every 5 s instead of 3.5 s, and stage 8 has one gunship fewer.
- Capital ships (Dreadnought, Carrier) turn slowly on the spot once in position, so every weak point faces the turret in turn. Weak points behind the hull are protected until then.
- Enemy beams are drawn to 13 m from the turret, not into the camera, and their impact spark is small. A 1.6 m wide boss beam ending at the camera filled the screen.

## 2026-11-22: M5 play test (Marko)

- Slow launchers need a clear ready indicator; the Seeker Torpedo needed help to hit; bosses must be big and keep moving; projectile weapons must be fast enough to need little lead; the Plasma Cannon bolt should be larger. All applied.

## 2026-11-22: M6 decisions (Claude)

- **Everything in the environment is built from data** (`config/environments.json`): sky, sun, fog, terrain, planet, moon and stars. No scene holds any of it, so a new time of day or a different planet is a data change.
- **Terrain is generated**, a disc of rings that get coarser with distance: level around the turret, dunes from 300 m, mountains from 4 km. It has no collision of its own; the flat ground plane still stops shots. Enemies never come lower than the ground allows (a unit test checks the ground stays under 40 m out to 3 km).
- **Planet, ring and moon are meshes 17 km away, drawn without fog**, lit from a direction set per time of day. **Stars are one mesh of points.** A star texture on the physical sky was tried first and gave blocky stars.
- **Tonemapper: ACES.** AgX was tried and washed the daytime sky out to grey.
- **The turret and guns get a flat ambient colour per time of day**, because their own camera has no sky behind it.
- **Tracers, flashes and bolts are MultiMesh pools** (`GlowBatch`) whose fading runs in the shader. One draw call per kind, nothing updated per effect per frame.
- **Particles are pooled one-shot emitters** (`ParticleBursts`): explosion fire, smoke, debris, impact sparks and shell casings. Smoke and fire fade out close to the camera so a kill at point-blank range cannot cover the screen.
- **Lens effects** (chromatic aberration, lens dirt, shield ripple) are one full-screen shader between the 3D picture and the HUD. It is hidden while idle, so it costs nothing most of the time.
- **Presets:** High uses TAA, SSAO, SSIL, SSR and volumetric fog at full resolution; Ultra adds SDFGI and longer shadows; Medium and Low render at 77 % and 67 % with FSR 2. Measured on the reference PC all four are far above the target, so nothing was traded away.
- **HUD:** the developer read-out is hidden by default (F1 shows it, debug builds); F3 cycles the graphics presets.

### Not done in M6 (honest list)

- **Heat distortion on beams** (spec 8). A refraction pass over thin moving beams needs its own render step; left out.
- **Orbital debris** in the sky. The ringed planet and the moon carry the "from space" feel.
- **Decals.** `max_decals` is in the presets but the game has no decals.
- **No downloaded art.** Every model, texture and effect is generated by the project itself, so there is still nothing third-party to credit. Real PBR texture sets (rock, sand, hull metal) would lift the look a lot; they are described in `docs/ART_BRIEF.md`.
- **Low preset on mid-range hardware is an estimate.** It cannot be measured on this PC.
