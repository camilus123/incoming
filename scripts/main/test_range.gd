extends PlayScene
## Test range: the turret and static target dummies placed from
## data/config/test_range.json. A debug scene for trying weapons; run it with
##   .\tools\godot.ps1 res://scenes/main/test_range.tscn
## and pick any weapons with
##   .\tools\godot.ps1 res://scenes/main/test_range.tscn ++ --primary=railgun --alternate=flak_barrage

@onready var _targets: Node3D = $Targets


func _ready() -> void:
	# The range is a sandbox: a fresh, unsaved run with the starting loadout.
	GameState.persistent = false
	GameState.new_run()
	# Any weapon can be tried here: ++ --primary=chain_gun --alternate=emp_burst
	for argument: String in OS.get_cmdline_user_args():
		for slot: String in GameState.SLOTS:
			if argument.begins_with("--%s=" % slot):
				GameState.loadout[slot] = argument.trim_prefix("--%s=" % slot)
	($Turret as Turret).apply_player_state()
	super._ready()
	_spawn_dummies()
	EventBus.data_reloaded.connect(_on_data_reloaded)


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
