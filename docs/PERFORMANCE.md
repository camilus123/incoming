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
