extends Node
## Autoload "UserSettings": the player's preferences, stored in user://settings.cfg.
##
## These are personal preferences (sensitivity, accessibility), not game
## balance. A value of -1 means "use the default from the data files".
## The settings menu arrives in M8; until then the file can be edited by hand.

signal changed(key: String)

const PATH: String = "user://settings.cfg"

const MOUSE_SENSITIVITY: String = "controls/mouse_sensitivity"
const MOUSE_SENSITIVITY_Y_SCALE: String = "controls/mouse_sensitivity_y_scale"
const INVERT_Y: String = "controls/invert_y"
const TURRET_SMOOTHING_S: String = "controls/turret_smoothing_s"
const FOV_HORIZONTAL_DEG: String = "video/fov_horizontal_deg"
const SCREEN_SHAKE: String = "accessibility/screen_shake"

const DEFAULTS: Dictionary = {
	MOUSE_SENSITIVITY: 1.0,
	MOUSE_SENSITIVITY_Y_SCALE: 1.0,
	INVERT_Y: false,
	TURRET_SMOOTHING_S: -1.0,
	FOV_HORIZONTAL_DEG: -1.0,
	SCREEN_SHAKE: 1.0,
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()


## Returns a setting, or its default if it was never set.
func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


## Returns a numeric setting, or `data_default` when the setting is -1 ("use data").
func get_float_or(key: String, data_default: float) -> float:
	var value: float = float(get_value(key))
	return data_default if value < 0.0 else value


## Changes a setting and notifies listeners. Call `save_settings()` to persist it.
func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	changed.emit(key)


func load_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key: String in DEFAULTS:
		var parts: PackedStringArray = key.split("/")
		if file.has_section_key(parts[0], parts[1]):
			_values[key] = file.get_value(parts[0], parts[1])


func save_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	for key: String in _values:
		var parts: PackedStringArray = key.split("/")
		file.set_value(parts[0], parts[1], _values[key])
	file.save(PATH)
