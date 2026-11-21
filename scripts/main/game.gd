extends PlayScene
## The main game scene: the turret against the stages.
##
## Command-line options (after `++`), in addition to those of PlayScene:
##   --stage=N   start at stage N (default 1)

@onready var _stages: StageManager = $StageManager


func _ready() -> void:
	super._ready()
	var first_stage: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			first_stage = maxi(1, argument.trim_prefix("--stage=").to_int())
	_stages.start_stage(first_stage)


func _on_demo_started() -> void:
	$StageManager.auto_advance = true
