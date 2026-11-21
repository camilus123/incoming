extends Control
## M0 test scene: shows the engine version and the data load status.
## It is replaced by the real main scene in later milestones.

@onready var _status: Label = $Status


func _ready() -> void:
	EventBus.data_reloaded.connect(_on_data_reloaded)
	_refresh(GameData.last_report)


func _on_data_reloaded(report: DataReport) -> void:
	_refresh(report)


func _refresh(report: DataReport) -> void:
	var lines: PackedStringArray = []
	lines.append("INCOMING  v%s" % ProjectSettings.get_setting("application/config/version", "?"))
	lines.append("Godot %s" % _engine_version())
	var pinned: String = ProjectSettings.get_setting("incoming/engine/pinned_version", "")
	if not pinned.is_empty() and pinned != _engine_version():
		lines.append("WARNING: this project is pinned to Godot %s" % pinned)
	lines.append("")
	lines.append("Data: " + report.summary())
	for issue: Dictionary in report.get_issues():
		lines.append(DataReport.format_issue(issue))
	if OS.is_debug_build():
		lines.append("")
		lines.append("F5 reloads the data files.")
	_status.text = "\n".join(lines)


func _engine_version() -> String:
	var info: Dictionary = Engine.get_version_info()
	return "%d.%d.%d-%s" % [info["major"], info["minor"], info["patch"], info["status"]]
