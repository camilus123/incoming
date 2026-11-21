class_name SaveSystem
extends RefCounted
## Reads and writes the run save as JSON (spec 3.11).
##
## Every save carries `save_version`. When the format changes, bump
## CURRENT_VERSION and add a step to `migrate()` that upgrades the previous
## version, so old saves keep working.

const CURRENT_VERSION: int = 1
const DEFAULT_PATH: String = "user://saves/run.json"


## Writes `data` (a plain dictionary) to `path`. Returns OK or an error code.
static func save_to(path: String, data: Dictionary) -> Error:
	var to_write: Dictionary = data.duplicate(true)
	to_write["save_version"] = CURRENT_VERSION
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_write, "  "))
	file.close()
	return OK


## Reads the save at `path`, upgraded to the current version.
## Returns {} if there is no save or it cannot be read.
static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Save file %s is damaged and was ignored" % path)
		return {}
	return migrate(json.data)


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Upgrades save data step by step to CURRENT_VERSION. Saves from a newer
## game version are rejected (returns {}).
static func migrate(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var version: int = int(result.get("save_version", 0))
	if version > CURRENT_VERSION:
		push_warning("Save file is from a newer version (%d) and was ignored" % version)
		return {}
	while version < CURRENT_VERSION:
		match version:
			0:
				# Version 0 (before versioning): nothing to convert.
				pass
		version += 1
	result["save_version"] = CURRENT_VERSION
	return result
