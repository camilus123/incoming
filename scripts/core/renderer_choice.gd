class_name RendererChoice
extends RefCounted
## The player's choice of rendering driver on Windows: Vulkan or DirectX 12.
##
## The engine picks its driver before any script runs, so the choice cannot
## be applied from the settings file directly. It is written to
## `override.cfg`, which Godot reads at start-up from the folder of the
## executable (or the project folder when run from the editor), and takes
## effect at the next start. The launch option
## `--rendering-driver vulkan|d3d12` still wins over it.

const SETTING: String = "rendering/rendering_device/driver.windows"
const DRIVERS: PackedStringArray = ["vulkan", "d3d12"]


## The driver the game will use at the next start.
static func get_chosen() -> String:
	var chosen: String = str(UserSettings.get_value(UserSettings.RENDERING_DRIVER))
	return chosen if DRIVERS.has(chosen) else "vulkan"


## Stores the choice and writes it where the engine will find it.
## Returns false if the override file could not be written.
static func choose(driver: String) -> bool:
	if not DRIVERS.has(driver):
		return false
	UserSettings.set_value(UserSettings.RENDERING_DRIVER, driver)
	UserSettings.save_settings()
	var file: ConfigFile = ConfigFile.new()
	var path: String = override_path()
	# Keep anything else that is already in the file.
	file.load(path)
	file.set_value("rendering", "rendering_device/driver.windows", driver)
	var error: Error = file.save(path)
	if error != OK:
		push_warning("RendererChoice: cannot write %s (error %d); start the game with --rendering-driver %s instead" % [path, error, driver])
	return error == OK


## Where the engine looks for `override.cfg`.
static func override_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://override.cfg")
	return OS.get_executable_path().get_base_dir().path_join("override.cfg")
