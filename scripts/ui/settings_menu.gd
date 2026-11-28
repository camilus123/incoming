class_name SettingsMenu
extends PanelContainer
## The settings screen: controls (sensitivity and rebinding), video, audio and
## accessibility. Shown from the main menu and the pause menu.
##
## Every control writes straight to [UserSettings]; the systems that care
## listen to its `changed` signal, so a change is felt at once. The file is
## saved when the screen closes. The one exception is the renderer, which the
## engine can only choose at start-up: it applies after a restart.

signal closed()

const ROW_LABEL_WIDTH: float = 330.0
const DRIVER_NAMES: Dictionary = {"vulkan": "Vulkan", "d3d12": "DirectX 12"}

var _tabs: TabContainer
var _binding_buttons: Dictionary = {}  # action name -> Button
## Action waiting for the player to press its new key or button ("" = none).
var _listening: String = ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(980.0, 720.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(UiTheme.label("SETTINGS", 28, UiTheme.COLOR_ACCENT))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_controls()
	_build_video()
	_build_audio()
	_build_accessibility()
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	var back: Button = UiTheme.button("Back", close)
	back.custom_minimum_size = Vector2(200.0, 44.0)
	footer.add_child(back)


## Saves the settings file and hides the screen.
func close() -> void:
	_listening = ""
	UserSettings.save_settings()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _listening.is_empty():
		if event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			close()
		return
	# Waiting for a new binding: the next key or mouse button is it.
	var entry: Dictionary = {}
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode != KEY_ESCAPE:
			entry = {"key": OS.get_keycode_string(key.physical_keycode)}
	elif mouse != null and mouse.pressed:
		entry = {"mouse_button": InputSetup.MOUSE_BUTTONS.find_key(mouse.button_index)}
		if entry["mouse_button"] == null:
			return
	else:
		return
	get_viewport().set_input_as_handled()
	var action: String = _listening
	_listening = ""
	if not entry.is_empty():
		InputSetup.rebind(action, [entry])
		Audio.play_event("ui_buy")
	_refresh_bindings()


# --- Controls ---------------------------------------------------------------

func _build_controls() -> void:
	var page: VBoxContainer = _page("Controls")
	_slider(page, "Mouse sensitivity", UserSettings.MOUSE_SENSITIVITY, 0.1, 4.0, 0.05, "%.2f")
	_slider(page, "Vertical sensitivity (relative)", UserSettings.MOUSE_SENSITIVITY_Y_SCALE, 0.25, 2.0, 0.05, "%.2f")
	_check(page, "Invert Y axis", UserSettings.INVERT_Y)
	page.add_child(HSeparator.new())
	page.add_child(UiTheme.label("Click a binding, then press the new key or mouse button. Esc cancels.", 14, UiTheme.COLOR_MUTED))
	var actions: Dictionary = GameData.loader.get_config("input").get("actions", {})
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	page.add_child(grid)
	for action_name: String in actions:
		var name_label: Label = UiTheme.label(str(actions[action_name].get("display_name", action_name)), 16)
		name_label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 0.0)
		grid.add_child(name_label)
		var bind: Button = UiTheme.button("", _start_listening.bind(action_name))
		bind.custom_minimum_size = Vector2(300.0, 36.0)
		grid.add_child(bind)
		_binding_buttons[action_name] = bind
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	row.add_child(UiTheme.button("Swap wheel direction", func() -> void:
		InputSetup.swap("power_to_weapons", "power_to_shields")
		_refresh_bindings()))
	row.add_child(UiTheme.button("Reset all bindings", func() -> void:
		InputSetup.reset_all()
		_refresh_bindings()))
	_refresh_bindings()


func _start_listening(action_name: String) -> void:
	_listening = action_name
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action_name: String in _binding_buttons:
		var bind: Button = _binding_buttons[action_name]
		bind.text = "press a key or button..." if action_name == _listening else InputSetup.describe(action_name)


# --- Video ------------------------------------------------------------------

func _build_video() -> void:
	var page: VBoxContainer = _page("Video")
	var presets: Dictionary = GameData.loader.get_config("graphics_presets").get("presets", {})
	var preset_names: Dictionary = {}
	for id: String in presets:
		preset_names[id] = presets[id].get("display_name", id)
	_option(page, "Graphics preset", preset_names, Graphics.preset_id, func(id: String) -> void:
		UserSettings.set_value(UserSettings.GRAPHICS_PRESET, id)
		Graphics.set_preset(id))
	var running: String = RenderingServer.get_current_rendering_driver_name()
	var note: Label = UiTheme.label("", 14, UiTheme.COLOR_MUTED)
	_option(page, "Renderer", DRIVER_NAMES, RendererChoice.get_chosen(), func(id: String) -> void:
		RendererChoice.choose(id)
		note.text = _renderer_note(running))
	note.text = _renderer_note(running)
	page.add_child(note)
	_check(page, "Fullscreen", UserSettings.FULLSCREEN)
	_check(page, "V-Sync", UserSettings.VSYNC)
	_slider(page, "Frame rate limit (0 = none)", UserSettings.MAX_FPS, 0.0, 360.0, 5.0, "%d")
	var fov_default: float = GameData.loader.get_config("turret").get("camera", {}).get("fov_horizontal_deg_at_16_9", 90.0)
	_slider(page, "Field of view (horizontal at 16:9)", UserSettings.FOV_HORIZONTAL_DEG, 60.0, 120.0, 1.0, "%d°", fov_default)
	_check(page, "Lens effects (colour fringing, lens dirt, shield ripple)", UserSettings.SCREEN_EFFECTS)


func _renderer_note(running: String) -> String:
	var chosen: String = RendererChoice.get_chosen()
	var text: String = "Running on %s." % DRIVER_NAMES.get(running, running)
	if chosen != running:
		text += " %s is used from the next start of the game." % DRIVER_NAMES.get(chosen, chosen)
	return text


# --- Audio ------------------------------------------------------------------

func _build_audio() -> void:
	var page: VBoxContainer = _page("Audio")
	for entry: Array in [["Master", UserSettings.VOLUME_MASTER], ["Music", UserSettings.VOLUME_MUSIC],
			["Effects", UserSettings.VOLUME_SFX], ["Weapons", UserSettings.VOLUME_WEAPONS],
			["Interface", UserSettings.VOLUME_UI], ["Alerts", UserSettings.VOLUME_ALERTS]]:
		_slider(page, "%s volume" % entry[0], entry[1], 0.0, 1.0, 0.05, "%d %%", -1.0, 100.0)


# --- Accessibility ----------------------------------------------------------

func _build_accessibility() -> void:
	var page: VBoxContainer = _page("Accessibility")
	_slider(page, "Screen shake", UserSettings.SCREEN_SHAKE, 0.0, 1.0, 0.05, "%d %%", -1.0, 100.0)
	var smoothing_default: float = GameData.loader.get_config("turret").get("aim", {}).get("smoothing_default_s", 0.03)
	_slider(page, "Turret weight (0 = none)", UserSettings.TURRET_SMOOTHING_S, 0.0, 0.25, 0.005, "%.3f s", smoothing_default)
	_check(page, "Lens effects", UserSettings.SCREEN_EFFECTS)
	page.add_child(UiTheme.label("Lens effects and screen shake can be switched off completely. Every key and button can be changed under Controls.", 14, UiTheme.COLOR_MUTED))


# --- Building blocks ----------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var page: VBoxContainer = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)
	return page


func _row(page: VBoxContainer, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	page.add_child(row)
	var name_label: Label = UiTheme.label(text, 16)
	name_label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 0.0)
	row.add_child(name_label)
	return row


## A slider bound to a setting. A stored value of -1 means "use the data
## default"; the slider then starts at `data_default`. `display_scale`
## multiplies the number shown (0..1 as a percentage).
func _slider(page: VBoxContainer, text: String, key: String, low: float, high: float, step: float, format: String, data_default: float = -1.0, display_scale: float = 1.0) -> void:
	var row: HBoxContainer = _row(page, text)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(360.0, 28.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stored: float = float(UserSettings.get_value(key))
	slider.value = data_default if stored < 0.0 and data_default >= 0.0 else stored
	row.add_child(slider)
	var value_label: Label = UiTheme.label("", 16, UiTheme.COLOR_ACCENT)
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(value_label)
	var show_value: Callable = func(value: float) -> void:
		value_label.text = format % ([roundi(value * display_scale)] if format.contains("%d") else [value * display_scale])
	show_value.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		UserSettings.set_value(key, int(value) if typeof(UserSettings.DEFAULTS.get(key)) == TYPE_INT else value)
		show_value.call(value))


func _check(page: VBoxContainer, text: String, key: String) -> void:
	var row: HBoxContainer = _row(page, text)
	var check: CheckButton = CheckButton.new()
	check.button_pressed = bool(UserSettings.get_value(key))
	check.toggled.connect(func(on: bool) -> void:
		Audio.play_event("ui_click")
		UserSettings.set_value(key, on))
	row.add_child(check)


## A drop-down. `choices` maps ids to the names shown.
func _option(page: VBoxContainer, text: String, choices: Dictionary, current: String, on_chosen: Callable) -> void:
	var row: HBoxContainer = _row(page, text)
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(260.0, 40.0)
	var ids: Array = choices.keys()
	for id: Variant in ids:
		option.add_item(str(choices[id]))
	option.selected = maxi(0, ids.find(current))
	option.item_selected.connect(func(index: int) -> void:
		Audio.play_event("ui_click")
		on_chosen.call(str(ids[index])))
	row.add_child(option)
