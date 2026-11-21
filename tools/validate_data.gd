extends SceneTree
## Command-line data validation.
##
## Usage (from the project folder):
##   godot --headless --path . --script res://tools/validate_data.gd
##   godot --headless --path . --script res://tools/validate_data.gd -- --data-root=res://tests/fixtures/bad_data
##
## Prints every problem as `ERROR file [field]: problem` and exits with code 1
## if there is at least one error, 0 otherwise.


func _init() -> void:
	var root: String = DataLoader.DEFAULT_ROOT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--data-root="):
			root = argument.trim_prefix("--data-root=")

	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all(root)
	DataValidator.validate(loader, report)

	print("Validating data in ", root)
	for issue: Dictionary in report.get_issues():
		print(DataReport.format_issue(issue))
	print(report.summary())
	print("RESULT: ", "FAILED" if report.has_errors() else "OK")
	quit(1 if report.has_errors() else 0)
