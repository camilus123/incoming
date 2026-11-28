extends Node3D
## The main menu, the project's first scene: continue or start a run, choose
## the difficulty, open the settings, quit. Behind it the camera pans slowly
## across the frontier sky.
##
## Automated starts (`--auto-demo`, `--benchmark`, `--stage=N`) skip the menu
## and go straight to the game, so the tools keep working.
## `--menu-shots=<folder>` saves a screenshot of the menu and of each settings
## page, then quits (used to check the menus without a player).

const GAME_SCENE: String = "res://scenes/main/game.tscn"
const PAN_DEG_PER_S: float = 1.5

var _camera: Camera3D
var _panel: PanelContainer
var _settings: SettingsMenu
var _continue: Button
var _new_run_button: Button
## A new run replaces the saved one, so the button asks once more first.
var _confirming_new_run: bool = false
var _difficulty_note: Label
var _yaw_deg: float = -25.0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--auto-demo", "--benchmark", "--new-run"] or argument.begins_with("--stage="):
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
			return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 6.0, 0.0)
	_camera.far = 30000.0
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()

	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title: Label = UiTheme.label("INCOMING", 96, UiTheme.COLOR_ACCENT)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(120.0, 110.0)
	root.add_child(title)
	var subtitle: Label = UiTheme.label("Ground turret defence", 22, UiTheme.COLOR_TEXT)
	subtitle.position = Vector2(126.0, 228.0)
	root.add_child(subtitle)

	_panel = PanelContainer.new()
	_panel.position = Vector2(120.0, 320.0)
	_panel.custom_minimum_size = Vector2(420.0, 0.0)
	root.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	_continue = UiTheme.button("Continue", _continue_run)
	column.add_child(_continue)
	_new_run_button = UiTheme.button("New run", _new_run)
	column.add_child(_new_run_button)
	column.add_child(_difficulty_row())
	_difficulty_note = UiTheme.label("", 13, UiTheme.COLOR_MUTED)
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_difficulty_note)
	column.add_child(UiTheme.button("Settings", _show_settings))
	column.add_child(UiTheme.button("Quit", func() -> void: get_tree().quit()))

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)
	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_panel.visible = true)
	centre.add_child(_settings)
	_refresh()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--menu-shots="):
			_save_menu_shots(argument.trim_prefix("--menu-shots="))


func _save_menu_shots(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().create_timer(1.5).timeout
	await _shot(directory.path_join("menu_main.png"))
	_show_settings()
	var tabs: TabContainer = _settings.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for index: int in tabs.get_tab_count():
		tabs.current_tab = index
		await get_tree().create_timer(0.3).timeout
		await _shot(directory.path_join("menu_settings_%s.png" % tabs.get_tab_title(index).to_lower()))
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _process(delta_s: float) -> void:
	if _camera == null:
		return
	_yaw_deg += PAN_DEG_PER_S * delta_s
	_camera.basis = Basis.from_euler(Vector3(deg_to_rad(16.0), deg_to_rad(-_yaw_deg), 0.0))


func _refresh() -> void:
	var has_save: bool = GameState.has_save()
	_continue.disabled = not has_save
	_continue.text = "Continue (stage %d, %s)" % [GameState.stage, GameState.get_difficulty().get("display_name", "")] if has_save else "Continue"
	_difficulty_note.text = "Difficulty applies to a new run. A run keeps the difficulty it was started on."


func _difficulty_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label: Label = UiTheme.label("Difficulty", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var levels: Dictionary = GameData.loader.get_config("difficulty").get("levels", {})
	var ids: Array = levels.keys()
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(200.0, 44.0)
	for id: Variant in ids:
		option.add_item(str(levels[id].get("display_name", id)))
	option.selected = maxi(0, ids.find(GameState.chosen_difficulty_id()))
	option.item_selected.connect(func(index: int) -> void:
		Audio.play_event("ui_click")
		UserSettings.set_value(UserSettings.DIFFICULTY, str(ids[index]))
		UserSettings.save_settings())
	row.add_child(option)
	return row


func _continue_run() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _new_run() -> void:
	if GameState.has_save() and not _confirming_new_run:
		_confirming_new_run = true
		_new_run_button.text = "Replace the saved run (stage %d)? Click again" % GameState.stage
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			_confirming_new_run = false
			_new_run_button.text = "New run")
		return
	GameState.new_run()
	GameState.save_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _show_settings() -> void:
	_panel.visible = false
	_settings.visible = true
