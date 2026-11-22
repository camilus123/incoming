# INCOMING

A single-player, first-person ground turret defence game. You are a gun turret on a frontier world, shooting down waves of enemies attacking from the sky and from orbit, and spending credits on a tech tree between stages.

Status: **M5 (content pass)**. All 20 weapons and 9 enemies are in. The game starts in the armoury before stage 1; stages 1 to 10 are authored (bosses at 5 and 10) and later ones are generated. The run is saved automatically every time the armoury opens. See `docs/CHANGELOG.md` and `docs/ROADMAP.md`.

## Controls

| Input | Action |
|---|---|
| Mouse | Aim |
| Left mouse button (hold) | Fire the Pulse Laser |
| Right mouse button (hold, then release) | Lock targets near the crosshair, release to launch missiles |
| Mouse wheel up / down | Shift power towards weapons / shields |
| Middle mouse click | Reset the power split to 50/50 |
| Esc | Pause and release the mouse |
| Enter or Space | Continue to the armoury after a stage, or start a new run after game over |
| R | After game over: back to the armoury before the lost stage |

In the armoury: left click buys an upgrade, right click refunds it, drag pans the tree and the wheel zooms. F2 adds 1,000 credits in debug builds.
| F5 (debug builds) | Reload all data files |
| F1 (debug builds) | Show or hide the developer read-out (fps, aim, power and weapon numbers) |
| F3 (debug builds) | Next graphics preset (Low, Medium, High, Ultra) |

Sensitivity, invert Y, turret weight, FOV and screen shake are stored in `user://settings.cfg` (settings menu comes in M8).

## Requirements

- **Godot 4.7.2-stable**, standard build (not .NET). The version is pinned in `project.godot` (`incoming/engine/pinned_version`); the boot screen warns if you run another version.
- Windows 11 x86-64. Renderer: Forward+. Physics: Jolt.
- Git LFS (binary assets are stored in LFS, see `.gitattributes`).

## Run

Open the project folder in the Godot editor and press F5, or from a terminal:

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
.\tools\godot.ps1
```

`tools\godot.ps1` uses `GODOT_BIN`, or `godot` from the PATH, and builds the import cache on a fresh clone.

Useful variants:

```powershell
.\tools\godot.ps1 ++ --stage=3          # jump straight into stage 3 (nothing is saved)
.\tools\godot.ps1 ++ --new-run          # discard the saved run
.\tools\godot.ps1 ++ --god              # the turret takes no damage
.\tools\godot.ps1 res://scenes/main/test_range.tscn   # practice targets
.\tools\godot.ps1 res://scenes/main/test_range.tscn ++ --primary=railgun --alternate=flak_barrage   # try any weapons
```

## Validate the data

```powershell
.\tools\validate_data.ps1
```

Checks every file under `data/` against its schema plus cross-file rules. Prints `ERROR file [field]: problem` lines and exits with code 1 if there are errors. Without the wrapper:

```powershell
godot --headless --path . --script res://tools/validate_data.gd
```

## Run the tests

```powershell
.\tools\run_tests.ps1
```

Runs the GUT unit tests in `tests/unit` headless.

## Automated demo and fps

```powershell
.\tools\run_demo.ps1
.\tools\run_benchmark.ps1 -Preset high   # scripted heavy fight, prints fps and writes a result file
```

The turret aims and fires by itself for 20 seconds in fullscreen with V-Sync off, then prints a `PERF` line with the average fps and 1 % lows. Add `-ScreenshotDir C:\some\folder` to save screenshots.

## Layout

| Folder | Contents |
|---|---|
| `data/` | All balance and content as JSON. Formats: `docs/DATA_FORMAT.md` |
| `assets/` | Models, textures, audio. Conventions: `docs/ASSETS.md`, wish list: `docs/ART_BRIEF.md`, licences: `assets/CREDITS.md` |
| `scripts/` | GDScript, statically typed, grouped by system |
| `scenes/` | Godot scenes |
| `tests/` | GUT tests and fixtures |
| `tools/` | Command-line scripts |
| `docs/` | Design, decisions, data formats, performance log, roadmap, changelog |

In debug builds, **F5** in the running game reloads all data files.

## Licence

Code: GPL-3.0 (see `LICENSE`). Third-party assets and addons: see `assets/CREDITS.md`.
