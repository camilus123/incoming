extends Node3D
## M1 test range: the turret, a simple environment and static target dummies
## placed from data/config/test_range.json.
##
## Command-line options (after `++`):
##   --auto-demo   aim and fire automatically, log fps, save screenshots, quit.

const ACTION_PAUSE: StringName = &"pause"
const ACTION_CAMERA_TOGGLE: StringName = &"camera_toggle"

@onready var _turret: Turret = $Turret
@onready var _targets: Node3D = $Targets


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_dummies()
	EventBus.data_reloaded.connect(_on_data_reloaded)
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if OS.get_cmdline_user_args().has("--auto-demo"):
		var demo: AutoDemo = AutoDemo.new()
		demo.name = "AutoDemo"
		demo.turret = _turret
		add_child(demo)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_CAMERA_TOGGLE) and OS.is_debug_build():
		EventBus.ui_message.emit("Third-person camera: coming soon")


func _notification(what: int) -> void:
	# Give the mouse back when the window loses focus.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and _turret.player_input_enabled and not get_tree().paused:
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _spawn_dummies() -> void:
	for child: Node in _targets.get_children():
		child.queue_free()
	var config: Dictionary = GameData.loader.get_config("test_range")
	var origin: Vector3 = _turret.get_aim_transform().origin
	for dummy_data: Dictionary in config.get("dummies", []):
		var dummy: TargetDummy = TargetDummy.new()
		dummy.setup(dummy_data, config.get("model", ""), config.get("respawn_s", 3.0))
		_targets.add_child(dummy)
		var direction: Vector3 = TurretAim.direction_from(dummy_data["yaw_deg"], dummy_data["pitch_deg"])
		dummy.global_position = origin + _turret.global_transform.basis * direction * float(dummy_data["distance_m"])


func _on_data_reloaded(_report: DataReport) -> void:
	_spawn_dummies()
