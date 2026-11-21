class_name DataLoader
extends RefCounted
## Loads every JSON data file listed in `<root>/schemas/index.json`.
##
## The index names two kinds of data:
## - configs: a single file with one object (e.g. config/power.json)
## - collections: a directory with one file per entry (e.g. weapons/)
##
## Each file is checked against its schema ([DataSchema]). Bad data never
## crashes: a broken config falls back to its schema defaults, a broken
## collection entry is skipped, and every problem lands in the [DataReport].

const DEFAULT_ROOT: String = "res://data"
const INDEX_FILE: String = "schemas/index.json"

const INDEX_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"configs": {
			"type": "array",
			"default": [],
			"items": {
				"type": "object",
				"fields": {
					"name": {"type": "string", "required": true, "non_empty": true},
					"file": {"type": "string", "required": true, "non_empty": true},
					"schema": {"type": "string", "required": true, "non_empty": true},
				},
			},
		},
		"collections": {
			"type": "array",
			"default": [],
			"items": {
				"type": "object",
				"fields": {
					"category": {"type": "string", "required": true, "non_empty": true},
					"directory": {"type": "string", "required": true, "non_empty": true},
					"schema": {"type": "string", "required": true, "non_empty": true},
					"id_field": {"type": "string", "default": "id", "non_empty": true},
				},
			},
		},
	},
}

var _root: String = DEFAULT_ROOT
var _configs: Dictionary = {}      # config name -> Dictionary
var _collections: Dictionary = {}  # category -> { id -> Dictionary }
var _sources: Dictionary = {}      # "category/id" -> file path


## Loads everything under `root` and returns the report of problems found.
func load_all(root: String = DEFAULT_ROOT) -> DataReport:
	_root = root.trim_suffix("/")
	_configs.clear()
	_collections.clear()
	_sources.clear()

	var report: DataReport = DataReport.new()
	var index_path: String = _root.path_join(INDEX_FILE)
	var raw_index: Variant = read_json(index_path, report)
	if raw_index == null:
		return report
	report.files_checked += 1
	var index: Variant = DataSchema.validate(raw_index, INDEX_SCHEMA, index_path, report)
	if not index is Dictionary:
		return report

	for entry: Dictionary in index["configs"]:
		_load_config(entry, report)
	for entry: Dictionary in index["collections"]:
		_load_collection(entry, report)
	return report


## Returns a config object by name (e.g. "power"), or {} if it is unknown.
func get_config(config_name: String) -> Dictionary:
	return _configs.get(config_name, {})


func has_config(config_name: String) -> bool:
	return _configs.has(config_name)


## Returns all valid entries of a collection as `{ id -> entry }`.
func get_category(category: String) -> Dictionary:
	return _collections.get(category, {})


## Returns one entry of a collection, or {} if it does not exist.
func get_entry(category: String, id: String) -> Dictionary:
	var entries: Dictionary = _collections.get(category, {})
	return entries.get(id, {})


func has_entry(category: String, id: String) -> bool:
	var entries: Dictionary = _collections.get(category, {})
	return entries.has(id)


## Names of all loaded configs and collections (for tools and debug views).
func get_config_names() -> PackedStringArray:
	return PackedStringArray(_configs.keys())


func get_category_names() -> PackedStringArray:
	return PackedStringArray(_collections.keys())


## File a config or collection entry came from, for error messages in
## cross-file checks. Use `source_of_config("power")` or `source_of("weapons", id)`.
func source_of_config(config_name: String) -> String:
	return _sources.get("config/" + config_name, "")


func source_of(category: String, id: String) -> String:
	return _sources.get(category + "/" + id, "")


## Reads and parses one JSON file. Returns null (and reports why) on failure.
static func read_json(path: String, report: DataReport) -> Variant:
	if not FileAccess.file_exists(path):
		report.add_error(path, "", "file not found")
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		report.add_error(path, "", "invalid JSON at line %d: %s" % [json.get_error_line() + 1, json.get_error_message()])
		return null
	if json.data == null:
		report.add_error(path, "", "file contains no data")
	return json.data


func _load_schema(path: String, report: DataReport) -> Dictionary:
	var raw: Variant = read_json(path, report)
	if raw == null:
		return {}
	if not raw is Dictionary or not (raw as Dictionary).has("type"):
		report.add_error(path, "", "a schema must be an object with a \"type\"")
		return {}
	return raw


func _load_config(entry: Dictionary, report: DataReport) -> void:
	var config_name: String = entry["name"]
	var file_path: String = _root.path_join(entry["file"])
	_configs[config_name] = {}
	_sources["config/" + config_name] = file_path
	var schema: Dictionary = _load_schema(_root.path_join(entry["schema"]), report)
	if schema.is_empty():
		return

	report.files_checked += 1
	var raw: Variant = read_json(file_path, report)
	var checked: Variant = null
	if raw != null:
		checked = DataSchema.validate(raw, schema, file_path, report)
	if not checked is Dictionary:
		report.add_warning(file_path, "", "using the built-in defaults from the schema instead")
		checked = DataSchema.defaults(schema)
	if checked is Dictionary:
		_configs[config_name] = checked


func _load_collection(entry: Dictionary, report: DataReport) -> void:
	var category: String = entry["category"]
	var id_field: String = entry["id_field"]
	var dir_path: String = _root.path_join(entry["directory"])
	var entries: Dictionary = {}
	_collections[category] = entries
	var schema: Dictionary = _load_schema(_root.path_join(entry["schema"]), report)
	if schema.is_empty():
		return

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		report.add_error(dir_path, "", "directory cannot be opened")
		return
	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "json":
			continue
		var file_path: String = dir_path.path_join(file_name)
		report.files_checked += 1
		var raw: Variant = read_json(file_path, report)
		if raw == null:
			continue
		var errors_before: int = report.error_count()
		var checked: Variant = DataSchema.validate(raw, schema, file_path, report)
		if report.error_count() > errors_before or not checked is Dictionary:
			report.add_warning(file_path, "", "entry skipped because of the errors above")
			continue
		var data: Dictionary = checked
		var id: String = str(data.get(id_field, ""))
		if id.is_empty():
			report.add_error(file_path, id_field, "entry has no id; skipped")
			continue
		if entries.has(id):
			report.add_error(file_path, id_field, "duplicate id \"%s\" (already defined in %s); skipped" % [id, source_of(category, id)])
			continue
		if id != file_name.get_basename():
			report.add_warning(file_path, id_field, "id \"%s\" does not match the file name" % id)
		entries[id] = data
		_sources[category + "/" + id] = file_path
