extends Node
## Autoload "Graphics": the active graphics preset.
##
## Presets are data (`data/config/graphics_presets.json`). This node picks one
## (command line `--preset=<id>`, else the player's setting, else the data
## default), applies everything that belongs to the window and the renderer,
## and tells the rest of the game through `changed`. The environment, the
## camera rig and the effects read the fields they care about with `get_value`.

signal changed()

const SHADOW_ATLAS_SIZE: Dictionary = {"off": 1024, "low": 2048, "medium": 4096, "high": 4096, "ultra": 8192}
const SHADOW_FILTER: Dictionary = {
	"off": RenderingServer.SHADOW_QUALITY_HARD,
	"low": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	"medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	"high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	"ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
}

## Id of the active preset (a key of "presets" in the data file).
var preset_id: String = ""
## The active preset's fields.
var preset: Dictionary = {}


func _ready() -> void:
	var wanted: String = str(UserSettings.get_value(UserSettings.GRAPHICS_PRESET))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="):
			wanted = argument.trim_prefix("--preset=")
	set_preset(wanted)
	EventBus.data_reloaded.connect(func(_report: DataReport) -> void: set_preset(preset_id))
	UserSettings.changed.connect(_on_setting_changed)
	apply_window_settings()


## Ids of all presets, in the order of the data file.
func get_preset_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_presets().keys())
	return ids


## Switches to a preset. An unknown id falls back to the data default.
func set_preset(id: String) -> void:
	var presets: Dictionary = _presets()
	if not presets.has(id):
		id = GameData.loader.get_config("graphics_presets").get("default", "high")
	if not presets.has(id) and not presets.is_empty():
		id = presets.keys()[0]
	preset_id = id
	preset = presets.get(id, {})
	apply()


## Switches to the next preset (debug key).
func cycle_preset() -> void:
	var ids: Array[String] = get_preset_ids()
	if ids.is_empty():
		return
	set_preset(ids[(ids.find(preset_id) + 1) % ids.size()])


## A field of the active preset.
func get_value(key: String, fallback: Variant) -> Variant:
	return preset.get(key, fallback)


## Applies the window and renderer part of the preset and notifies listeners.
func apply() -> void:
	var viewport: Viewport = get_tree().root
	var upscaler: String = get_value("upscaler", "none")
	var antialiasing: String = get_value("antialiasing", "taa")
	match upscaler:
		"fsr1":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = clampf(float(get_value("render_scale", 1.0)), 0.25, 2.0)
	# FSR 2 brings its own temporal anti-aliasing; running TAA on top only blurs.
	viewport.use_taa = antialiasing == "taa" and upscaler != "fsr2"
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED

	var shadows: String = get_value("shadows", "high")
	RenderingServer.directional_shadow_atlas_set_size(int(SHADOW_ATLAS_SIZE.get(shadows, 4096)), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER.get(shadows, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
	changed.emit()


## Fullscreen, V-Sync and the frame rate limit from the player's settings.
## Automated runs (demo, benchmark, tests) set their own and are left alone.
func apply_window_settings() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or arguments.has("--auto-demo") or arguments.has("--benchmark"):
		return
	# A window asked for on the command line stays a window.
	if not OS.get_cmdline_args().has("--windowed") and not OS.get_cmdline_args().has("-w"):
		var fullscreen: bool = UserSettings.get_value(UserSettings.FULLSCREEN)
		get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(UserSettings.get_value(UserSettings.VSYNC)) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = maxi(0, int(UserSettings.get_value(UserSettings.MAX_FPS)))


func _on_setting_changed(key: String) -> void:
	if key in [UserSettings.FULLSCREEN, UserSettings.VSYNC, UserSettings.MAX_FPS]:
		apply_window_settings()


func _presets() -> Dictionary:
	return GameData.loader.get_config("graphics_presets").get("presets", {})
