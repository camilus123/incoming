extends PlayScene
## The main game scene: the turret, the stages and the shop between them.
##
## Command-line options (after `++`), in addition to those of PlayScene:
##   --stage=N    start directly in stage N, skipping the shop (nothing is saved)
##   --new-run    discard the saved run and start again
##   --demo-buy   with --auto-demo: buy every affordable upgrade in each shop
##   --demo-shop-seconds=N   with --auto-demo: keep each shop open for N seconds
##   --demo-credits=N        with --auto-demo: start the run with N credits
##   --demo-from-stage=N     with --auto-demo: the run starts in the armoury before stage N

@onready var _stages: StageManager = $StageManager


func _ready() -> void:
	super._ready()
	_stages.state_changed.connect(_on_stage_state_changed)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var direct_stage: int = 0
	for argument: String in arguments:
		if argument.begins_with("--stage="):
			direct_stage = maxi(1, argument.trim_prefix("--stage=").to_int())
	var benchmark: bool = arguments.has("--benchmark")
	if arguments.has("--auto-demo") or direct_stage > 0 or benchmark:
		# Debug and demo runs never touch the player's save.
		GameState.persistent = false
		GameState.new_run()
		for argument: String in arguments:
			if argument.begins_with("--demo-credits="):
				GameState.credits = argument.trim_prefix("--demo-credits=").to_int()
			elif argument.begins_with("--demo-from-stage="):
				GameState.stage = maxi(1, argument.trim_prefix("--demo-from-stage=").to_int())
	elif arguments.has("--new-run"):
		GameState.new_run()
	if benchmark:
		var settings: Dictionary = GameData.loader.get_config("benchmark")
		# The same seed gives the same fight on every run.
		seed(int(settings.get("seed", 1)))
		_stages.start_custom_stage(GameData.loader.get_config("benchmark_stage"), int(settings.get("seed", 1)))
	elif direct_stage > 0:
		GameState.stage = direct_stage
		_stages.start_stage(direct_stage)
	else:
		_stages.open_shop()


func _on_demo_started() -> void:
	$StageManager.auto_advance = true
	$StageManager.auto_buy = OS.get_cmdline_user_args().has("--demo-buy")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-shop-seconds="):
			$StageManager.auto_shop_s = argument.trim_prefix("--demo-shop-seconds=").to_float()


func _can_pause() -> bool:
	return _stages.state != StageManager.State.SHOP


func _on_stage_state_changed(state: StageManager.State) -> void:
	# The shop needs the mouse pointer; fighting needs it captured.
	if get_tree().paused:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if state == StageManager.State.SHOP else Input.MOUSE_MODE_CAPTURED
