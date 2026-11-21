extends Node
## Autoload "GameData": the loaded data files and the asset resolver.
##
## Other systems read data through `GameData.loader` and load assets through
## `GameData.assets`. In debug builds F5 reloads all data files without
## restarting; listeners get `EventBus.data_reloaded`.

const ACTION_RELOAD_DATA: StringName = &"debug_reload_data"

## Loaded and validated data. Replaced as a whole on every reload.
var loader: DataLoader = DataLoader.new()
## Asset ID lookup, configured from the asset manifest.
var assets: AssetResolver = AssetResolver.new()
## Report of the most recent load.
var last_report: DataReport = DataReport.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build():
		_register_debug_actions()
	reload()


## Loads all data files again, validates them and notifies listeners.
func reload() -> DataReport:
	var new_loader: DataLoader = DataLoader.new()
	var report: DataReport = new_loader.load_all()
	DataValidator.validate(new_loader, report)
	loader = new_loader
	assets.configure(loader.get_config("asset_manifest"))
	last_report = report
	report.push_to_log()
	print("Data loaded: ", report.summary())
	EventBus.data_reloaded.emit(report)
	return report


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(ACTION_RELOAD_DATA):
		reload()
		get_viewport().set_input_as_handled()


func _register_debug_actions() -> void:
	if InputMap.has_action(ACTION_RELOAD_DATA):
		return
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F5
	InputMap.add_action(ACTION_RELOAD_DATA)
	InputMap.action_add_event(ACTION_RELOAD_DATA, key)
