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
