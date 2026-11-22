class_name PlayScene
extends Node3D
## Shared base of the scenes the player plays in (game, test range):
## mouse capture, pause, the reserved camera key and the automated demo.
##
## Command-line options (after `++`):
##   --auto-demo   aim and fire automatically, log fps, save screenshots, quit
##   --god         the turret takes no damage
##   --benchmark   (game scene) play the benchmark stage with the automatic
##                 gunner and write the result to a file; see config/benchmark.json

const ACTION_PAUSE: StringName = &"pause"
const ACTION_CAMERA_TOGGLE: StringName = &"camera_toggle"

const MAIN_MENU_SCENE: String = "res://scenes/main/main_menu.tscn"

@onready var _turret: Turret = $Turret

var _pause_menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_set_paused.bind(false))
	_pause_menu.restart_requested.connect(func() -> void:
		_set_paused(false)
		_restart_stage())
	_pause_menu.main_menu_requested.connect(_go_to_main_menu)
	var debug_menu: DebugMenu = DebugMenu.new()
	debug_menu.name = "DebugMenu"
	add_child(debug_menu)
	var lens: ScreenEffects = ScreenEffects.new()
	lens.name = "ScreenEffects"
	add_child(lens)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var benchmark: bool = arguments.has("--benchmark")
	if arguments.has("--god") or benchmark:
		_turret.invulnerable = true
	if arguments.has("--auto-demo") or benchmark:
		var demo: AutoDemo = AutoDemo.new()
		demo.name = "AutoDemo"
		demo.turret = _turret
		demo.benchmark = benchmark
		add_child(demo)
		_on_demo_started()
	# This node keeps running while paused so it can un-pause; everything else stops.
	for child: Node in get_children():
		if child.process_mode == Node.PROCESS_MODE_INHERIT:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE


## Scenes can forbid pausing in some states (the shop has nothing to pause).
func _can_pause() -> bool:
	return true


## Scenes with stages restart the current one here.
func _can_restart() -> bool:
	return false


func _restart_stage() -> void:
	pass


## Leaves for the main menu. The run was saved at the last armoury visit.
func _go_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Hook for scenes that need to prepare for the automated demo.
func _on_demo_started() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE) and (_can_pause() or get_tree().paused):
		# In the settings screen Esc goes back to the pause menu, not to the game.
		if not _pause_menu.is_in_settings():
			_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3 and OS.is_debug_build():
		Graphics.cycle_preset()
		EventBus.ui_message.emit("Graphics preset: %s" % Graphics.get_value("display_name", Graphics.preset_id))
	elif event.is_action_pressed(ACTION_CAMERA_TOGGLE) and OS.is_debug_build():
		EventBus.ui_message.emit("Third-person camera: coming soon")


func _notification(what: int) -> void:
	# Give the mouse back when the window loses focus.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and _turret.player_input_enabled and not get_tree().paused and _can_pause():
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_menu.set_open(paused, _can_restart())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (paused or not _can_pause()) else Input.MOUSE_MODE_CAPTURED
