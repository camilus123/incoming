# Performance log

Targets on the reference PC (Ryzen 9 5950X, 64 GB, Radeon RX 9070) at 3440×1440, High preset, busiest stages: **≥ 165 fps average, ≥ 120 fps 1 % lows**. Low preset: 60 fps on GTX 1660 / RX 6600 class hardware (cannot be measured here; reported as an estimate).

Measure, don't guess. One entry per milestone.

## M0 (2026-11-21)

No gameplay yet, so there is nothing meaningful to measure. The project starts on Vulkan 1.4 Forward+ on the RX 9070 and shows the boot scene. The benchmark mode arrives in M7; from M1 on, each entry lists average fps and 1 % lows for a fixed test scene.

## M1 (2026-11-21)

Automated demo (`tools\run_demo.ps1`), 20 s, fullscreen 3440×1440, V-Sync off, test range with 14 targets, both weapons firing. No graphics presets exist yet; this is the default environment (procedural sky, sun with shadows, glow, fog) plus the viewmodel pass with 4× MSAA.

| Resolution | Average fps | 1 % low | Worst frame |
|---|---|---|---|
| 3440×1440 | 312 | 115 | 8.9 ms |

Notes:
- The scene is almost empty, so this mainly shows the fixed cost of the two-camera setup.
- Saving a screenshot stalls a frame for 200 to 600 ms (GPU read-back), so fps is measured in runs without screenshots.
- The 1 % low sits just under the 120 fps target while the average is far above it. To investigate in M7: first-use shader/pipeline compilation of effects, and per-frame spikes from GDScript.

## M2 (2026-11-21)

Automated demo, 60 s of stage 3 (bombers, interceptors and drone swarms, up to about 40 enemies), fullscreen 3440×1440, V-Sync off, god mode so the run is not cut short.

| Resolution | Average fps | 1 % low | Worst frame |
|---|---|---|---|
| 3440×1440 | 255 | 113 | 10.2 ms |

Notes:
- Every enemy is still its own node with its own script; the MultiMesh swarm manager and pooling come in M7.
- The 1 % low is again slightly under the 120 fps target while the worst frame is only 10 ms, so the lows are many mildly slow frames rather than hitches. Likely candidates: the group lookups per missile detonation and lock search, and per-frame HUD redraw. To be profiled in M7.

## M3 (2026-11-21)

Same run as M2 (stage 3, 45 to 60 s, fullscreen 3440×1440, V-Sync off, god mode), now with the shield dome.

| Build | Average fps | 1 % low | Worst frame |
|---|---|---|---|
| M2 (no dome) | 255 | 113 | 10.2 ms |
| M3, first dome shader | 160 | 112 | 11.4 ms |
| M3, ripple loop skipped when idle | 206 | 113 | 10.1 ms |

Notes:
- The dome covers the whole screen, so every per-pixel instruction in its shader costs about 5 million evaluations per frame. Skipping the 8-impact ripple loop when no hit is active recovered most of the loss.
- God mode is a worst case for the dome: drones ram the turret constantly, so ripples are active most of the time. In normal play the dome is idle more often.
- Remaining cost to look at in M7: the hex lattice maths per pixel (could come from a small texture instead), and drawing the dome at reduced resolution.

### Shield styles (2026-11-21)

Stage 3, fullscreen 3440×1440, god mode (drones ram the turret constantly, so the shield effect is active most of the time):

| Shield style | Average fps | 1 % low |
|---|---|---|
| none (overlay disabled, experiment) | 279 | 113 |
| dome | 198 | 112 |
| conformal | 144 | 111 |

Idle on the test range both styles are equal (218 and 226 fps). Under fire the conformal skin is unexpectedly expensive. Experiments ruled out the per-frame uniform updates (158 fps without them) and viewmodel MSAA (160 fps with it off); the cost comes from having the overlay on the roughly 40 turret meshes at all during the stage. **To investigate in M7** (candidates: overlay draw calls interacting with the explosion lights on the viewmodel layer, merging the placeholder model into fewer meshes).

## M5 (2026-11-22)

Automated demo, 60 s, fullscreen 3440×1440, V-Sync off, god mode, starting loadout.

| Stage | Average fps | 1 % low | Worst frame |
|---|---|---|---|
| 9 (carrier launching drones, escorts) | 160 | 111 | 11.4 ms |
| 10 (Dreadnought, frigate, escorts) | 160 | 112 | 9.5 ms |

Both are just under the targets (165 average, 120 for the 1 % lows). Nothing is pooled on the enemy side yet and every drone is its own node; that, the per-frame group lookups in the projectile system, and the HUD redraw are the first things for M7.

## M6 (2026-11-22)

Automated demo, 45 s, fullscreen 3440×1440, V-Sync off, god mode, starting loadout. New since M5: the whole environment, particles, lens effects, and tracers, flashes and bolts as MultiMesh pools.

| Stage | Preset | Average fps | Median fps | 1 % low | Worst frame |
|---|---|---|---|---|---|
| 3 (dusk, swarms) | Low | 593 | 603 | 435 | 7.9 ms |
| 3 | Medium | 443 | 450 | 346 | 5.9 ms |
| 3 | High | 347 | 346 | 271 | 7.0 ms |
| 3 | Ultra | 291 | 294 | 233 | 5.8 ms |
| 10 (night, Dreadnought) | Low | 575 | 587 | 401 | 34.5 ms |
| 10 | Medium | 434 | 441 | 318 | 34.1 ms |
| 10 | High | 343 | 345 | 257 | 35.2 ms |
| 10 | Ultra | 291 | 296 | 217 | 36.2 ms |

High is at about twice the target (165 average, 120 for the 1 % lows) in both stages. Stage 10 has one frame of about 35 ms in every run (first appearance of the Dreadnought); to look at in M7.

### The "1 % low of 111 to 115 fps" of M1 to M5 was not the game

Every earlier entry in this file shows a 1 % low just under 120 fps, whatever the scene. In M6 a frame-time log (`--demo-frame-log=<file>`) showed why: for long stretches every single frame took exactly 8.42 ms (119 fps), in a small window as much as in fullscreen and on Low as much as on High. That is a frame limiter, not load. It came and went between runs made minutes apart with identical code, and it was gone in all the runs in the table above.

The cause is outside the game. The game sets no frame limit and V-Sync is off during the demo. 119 fps is half of the 240 Hz of the display, which is typical of a driver feature (for example Radeon Chill, Frame Rate Target Control or frame generation pacing) or of another program holding the frame rate down. **The earlier numbers in this file are therefore lower bounds**, measured partly with that limiter active: the M5 figures of 160 fps for stages 9 and 10 were the limiter, not the game.

**Confirmed by Marko on 2026-11-22: it was the frame rate cap in AMD Adrenalin.** With the cap on, the game cannot exceed 119 fps on this PC, so measure with it off.

Useful for measuring: `tools\run_demo.ps1 -Stage 3 -God -Seconds 45 --preset=high`, plus `"--demo-frame-log=C:\temp\frames.txt"` for every frame time. The PERF line now includes the preset and the median.

## M7 (2026-11-22): benchmark mode and the performance pass

### The benchmark

`tools\run_benchmark.ps1` (or `--benchmark` on the command line) plays `data/stages/benchmark.json` with the automatic gunner for 70 s and writes a JSON file: summary, a per-second timeline (fps, enemies on the field, draw calls, nodes) and every frame time in order. The fight is far heavier than any real stage: three waves with 300 drones, 18 interceptors, a carrier, the Dreadnought and more, about 115 enemies in the air at once. The turret cannot die, so whole swarms ram it, which is the worst case for effects. The same seed gives the same fight each run.

```
.\tools\run_benchmark.ps1 -Preset high -OutDir C:\temp\bench
```

Turn off any frame rate cap in the graphics driver first (see the M6 entry).

### Results (reference PC, 3440×1440, Vulkan, V-Sync off)

| Preset | Average fps | Median fps | 1 % low | Worst frame |
|---|---|---|---|---|
| Low (FSR 2 performance) | 469 | 477 | 285 | 4.8 ms |
| Medium (FSR 2 balanced) | 424 | 443 | 261 | 5.1 ms |
| High (FSR 2 quality) | 367 | 380 | 237 | 7.6 ms |
| Ultra (FSR 2 native) | 257 | 260 | 204 | 5.9 ms |

Target for High: at least 165 average and 120 for the 1 % lows. **Met on every preset, Ultra included**, in a fight several times heavier than stage 10.

### What the pass changed, in the order it was measured

Ultra, the benchmark, same PC:

| Step | Average fps | 1 % low | Worst frame |
|---|---|---|---|
| Start of M7 | 203 | 52 | 34 ms |
| Fire and smoke skipped for explosions at the camera | 250 | 163 | 34 ms |
| Swarm MultiMesh, manager loop, pooling, target registry | 252 | 195 | 31 ms |
| Idle shield not drawn, glow shader prewarmed | 257 | 204 | 5.9 ms |

1. **Particles at the camera were the whole problem.** The timeline showed 250 fps with 116 enemies in the air and 50 to 80 fps a few seconds later, while the enemy count was *falling*: the drones were ramming the turret. Switching effects off one at a time found the cause: fire and smoke puffs from explosions a few metres from the camera. Their material fades them out that close, but each still covered most of the screen, hundreds at a time. Explosions within 30 m of the camera now show debris only.
2. **Swarm drones** have no model of their own any more. One MultiMesh per model draws the whole swarm, and the enemy manager advances all members in one loop. On Low, where the CPU is the limit, the 1 % low went from 221 to 268 fps.
3. **Pooling:** destroyed swarm drones and enemy projectiles are kept and reused after a 1.5 s rest. Big ships are still created per spawn (a handful per stage).
4. **No group lookups in hot loops:** proximity fuses, splash damage, lock-on and beam chains read `CombatTarget.registry` instead of asking the scene tree for a new array each call. The hit-shape distance assist runs about 8 times a second per enemy instead of every frame.
5. **The one long frame per stage** (30 to 35 ms, first seen in M6) was the renderer building the shader of shield bubbles and weak point markers the first time one was drawn. Two pin-sized ones are now drawn during the stage intro.
6. **An idle shield is not drawn.** Since the shield became invisible until hit, its full-screen shader was running for nothing.

### Checked against the list in spec section 9

| Technique | State |
|---|---|
| Pooling: projectiles, missiles, effects | done since M1 to M6 (fixed pools, MultiMesh batches) |
| Pooling: enemies | swarm enemies and enemy projectiles; big ships are not pooled |
| Pooling: decals, audio players | the game has neither yet (audio is M8) |
| Hitscan by raycast, fast projectiles by ray sweep | done since M1 and M5 |
| Swarms as MultiMesh with a lightweight manager | done |
| Physics layers | enemies and their projectiles are query-only areas that test against nothing |
| LOD and visibility ranges | Godot's automatic mesh LOD is on for all imported models. No hand-set visibility ranges: enemies must stay visible out to 4 km and the placeholder models have about 100 triangles each. Particle effects have a view distance per preset. Revisit with final art |
| No per-frame allocations in hot loops | group lookups removed; reused DamageInfo and ray query objects since M1 |
| Caps on particle systems | per preset (`max_active_particle_systems`, `particle_density`) |
| Benchmark mode | done |

### Still open

- Low on mid-range hardware (GTX 1660 / RX 6600 class) remains an estimate; it cannot be measured on this PC. Low renders at half resolution with no SSAO, reflections or volumetric fog, and the CPU side alone holds 285 fps at the 1 % low here.
- DirectX 12 gave lower 1 % lows than Vulkan in one stage 10 run (158 against 194 fps). Not investigated.
