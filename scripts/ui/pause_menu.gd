class_name PauseMenu
extends CanvasLayer
## The pause menu: resume, settings, restart the stage, back to the main menu,
## quit. Shown by the play scene while the game is paused.

signal resume_requested()
signal restart_requested()
signal main_menu_requested()

const CANVAS_LAYER: int = 40

var _menu: PanelContainer
var _settings: SettingsMenu
var _restart: Button


func _ready() -> void:
	layer = CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_menu = PanelContainer.new()
	_menu.theme = UiTheme.get_theme()
	_menu.custom_minimum_size = Vector2(380.0, 0.0)
	centre.add_child(_menu)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_menu.add_child(column)
	column.add_child(UiTheme.label("PAUSED", 30, UiTheme.COLOR_ACCENT))
	column.add_child(UiTheme.button("Resume", func() -> void: resume_requested.emit()))
	column.add_child(UiTheme.button("Settings", _show_settings))
	_restart = UiTheme.button("Restart stage", func() -> void: restart_requested.emit())
	column.add_child(_restart)
	column.add_child(UiTheme.button("Main menu", func() -> void: main_menu_requested.emit()))
	column.add_child(UiTheme.button("Quit to desktop", func() -> void: get_tree().quit()))
	column.add_child(UiTheme.label("Progress is saved at every visit to the armoury.", 13, UiTheme.COLOR_MUTED))

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_menu.visible = true)
	centre.add_child(_settings)


## Shows or hides the menu. `can_restart` is false where there is no stage to
## restart (the test range).
func set_open(open: bool, can_restart: bool = true) -> void:
	visible = open
	_menu.visible = true
	_settings.visible = false
	_restart.disabled = not can_restart


## True while the settings screen is in front (Esc then closes it, not the pause).
func is_in_settings() -> bool:
	return visible and _settings.visible


func _show_settings() -> void:
	_menu.visible = false
	_settings.visible = true
