class_name DataReport
extends RefCounted
## Collects problems found while loading and validating data files.
##
## Every issue records the file, the field (dotted path, may be empty) and a
## human-readable problem, so a designer can fix the JSON without reading code.

enum Severity { WARNING, ERROR }

## Number of JSON files that were read.
var files_checked: int = 0

var _issues: Array[Dictionary] = []
var _error_count: int = 0
var _warning_count: int = 0


## Records a problem that makes a value or entry unusable.
func add_error(file: String, field: String, problem: String) -> void:
	_issues.append({"severity": Severity.ERROR, "file": file, "field": field, "problem": problem})
	_error_count += 1


## Records a problem that is suspicious but does not stop the data being used.
func add_warning(file: String, field: String, problem: String) -> void:
	_issues.append({"severity": Severity.WARNING, "file": file, "field": field, "problem": problem})
	_warning_count += 1


func error_count() -> int:
	return _error_count


func warning_count() -> int:
	return _warning_count


func has_errors() -> bool:
	return _error_count > 0


## Returns all issues in the order they were found.
## Each is `{severity, file, field, problem}`.
func get_issues() -> Array[Dictionary]:
	return _issues


## Returns true if any issue's problem text contains `text` (handy in tests).
func has_issue_containing(text: String) -> bool:
	for issue: Dictionary in _issues:
		if str(issue["problem"]).contains(text):
			return true
	return false


## Formats one issue as `ERROR file [field]: problem`.
static func format_issue(issue: Dictionary) -> String:
	var label: String = "ERROR  " if issue["severity"] == Severity.ERROR else "WARNING"
	var field: String = issue["field"]
	if field.is_empty():
		return "%s %s: %s" % [label, issue["file"], issue["problem"]]
	return "%s %s [%s]: %s" % [label, issue["file"], field, issue["problem"]]


## One-line summary, e.g. `6 files checked, 0 errors, 1 warning`.
func summary() -> String:
	return "%d files checked, %d errors, %d warnings" % [files_checked, _error_count, _warning_count]


## Full multi-line report: every issue followed by the summary.
func format_text() -> String:
	var lines: PackedStringArray = []
	for issue: Dictionary in _issues:
		lines.append(format_issue(issue))
	lines.append(summary())
	return "\n".join(lines)


## Sends every issue to the Godot log (errors as errors, warnings as warnings).
func push_to_log() -> void:
	for issue: Dictionary in _issues:
		if issue["severity"] == Severity.ERROR:
			push_error(format_issue(issue))
		else:
			push_warning(format_issue(issue))
