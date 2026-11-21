# INCOMING

A single-player, first-person ground turret defence game. You are a gun turret on a frontier world, shooting down waves of enemies attacking from the sky and from orbit, and spending credits on a tech tree between stages.

Status: **M1 (core turret and shooting)**. The game starts in a test range with practice targets. See `docs/CHANGELOG.md` and `docs/ROADMAP.md`.

## Controls

| Input | Action |
|---|---|
| Mouse | Aim |
| Left mouse button (hold) | Fire the Pulse Laser |
| Right mouse button (hold, then release) | Lock targets near the crosshair, release to launch missiles |
| Esc | Pause and release the mouse |
| F5 (debug builds) | Reload all data files |

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
