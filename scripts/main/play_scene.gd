class_name PlayScene
extends Node3D
## Shared base of the scenes the player plays in (game, test range):
## mouse capture, pause, the reserved camera key and the automated demo.
##
## Command-line options (after `++`):
##   --auto-demo   aim and fire automatically, log fps, save screenshots, quit
##   --god         the turret takes no damage

const ACTION_PAUSE: StringName = &"pause"
const ACTION_CAMERA_TOGGLE: StringName = &"camera_toggle"

@onready var _turret: Turret = $Turret


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--god"):
		_turret.invulnerable = true
	if arguments.has("--auto-demo"):
		var demo: AutoDemo = AutoDemo.new()
		demo.name = "AutoDemo"
		demo.turret = _turret
		add_child(demo)
		_on_demo_started()
	# This node keeps running while paused so it can un-pause; everything else stops.
	for child: Node in get_children():
		if child.process_mode == Node.PROCESS_MODE_INHERIT:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE


## Scenes can forbid pausing in some states (the shop has nothing to pause).
func _can_pause() -> bool:
	return true


## Hook for scenes that need to prepare for the automated demo.
func _on_demo_started() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE) and (_can_pause() or get_tree().paused):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_CAMERA_TOGGLE) and OS.is_debug_build():
		EventBus.ui_message.emit("Third-person camera: coming soon")


func _notification(what: int) -> void:
	# Give the mouse back when the window loses focus.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and _turret.player_input_enabled and not get_tree().paused and _can_pause():
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (paused or not _can_pause()) else Input.MOUSE_MODE_CAPTURED
