# INCOMING

A single-player, first-person ground turret defence game. You are a gun turret on a frontier world, shooting down waves of enemies attacking from the sky and from orbit, and spending credits on a tech tree between stages.

Status: **all eight milestones are built (M8, polish).** 20 weapons, 9 enemies, stages 1 to 10 with bosses at 5 and 10 and generated stages after that, a tech tree of 79 upgrades, four graphics presets, sound, menus and a Windows build. The run is saved automatically every time the armoury opens. See `docs/CHANGELOG.md` and `docs/ROADMAP.md`.

## Controls

Every binding can be changed under Settings, Controls.

| Input | Action |
|---|---|
| Mouse | Aim |
| Left mouse button (hold) | Fire the primary weapon |
| Right mouse button | Fire the alternate weapon (missiles: hold to lock, release to launch) |
| Mouse wheel up / down | Shift power towards weapons / shields |
| Middle mouse click | Reset the power split to 50/50 |
| Tab (hold) | Stage stats and what is in the air |
| Esc | Pause menu (resume, settings, restart stage, main menu, quit) |
| Enter or Space | Continue to the armoury after a stage, or start a new run after game over |
| R | After game over: back to the armoury before the lost stage |

In the armoury: left click buys an upgrade, right click refunds it, drag pans the tree and the wheel zooms.

Debug builds only (the editor and `export_windows.ps1 -Debug`):

| Key | Action |
|---|---|
| F1 | Developer read-out (fps, aim, power and weapon numbers) |
| F2 | In the armoury: 1,000 credits |
| F3 | Next graphics preset |
| F4 | Debug menu: credits, skip stage, spawn an enemy, god mode, show hit shapes |
| F5 | Reload all data files |

Settings are stored in `user://settings.cfg` (on Windows: `%APPDATA%\Godot\app_userdata\INCOMING\`), the run in `user://saves/run.json`.

## Windows build

```powershell
.\tools\export_windows.ps1
```

writes `build\windows\INCOMING.exe` and `INCOMING.pck`; copy both anywhere and run the exe. It needs the Godot export templates for the pinned version (Godot editor: Editor, Manage Export Templates, Download and Install).

Launch options: `--rendering-driver d3d12` or `vulkan` picks the renderer for one start (Settings, Video stores a lasting choice); after `++` the game's own options work, for example `INCOMING.exe ++ --preset=high`.

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
