extends GutTest
## Tests for DataSchema: type checks, ranges, defaults and error reporting.

const SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "string", "required": true, "non_empty": true},
		"hp": {"type": "number", "min": 1, "max": 1000, "default": 50},
		"count": {"type": "int", "default": 1},
		"kind": {"type": "string", "enum": ["energy", "kinetic", "explosive"], "default": "energy"},
		"tags": {"type": "array", "default": [], "items": {"type": "string"}},
		"flag": {"type": "bool", "default": false},
	},
}

var _report: DataReport


func before_each() -> void:
	_report = DataReport.new()


func _check(value: Variant) -> Variant:
	return DataSchema.validate(value, SCHEMA, "test.json", _report)


func test_valid_object_passes_unchanged() -> void:
	var result: Dictionary = _check({"id": "a", "hp": 20, "count": 3, "kind": "kinetic", "tags": ["x"], "flag": true})
	assert_eq(_report.error_count(), 0)
	assert_eq(_report.warning_count(), 0)
	assert_eq(result["hp"], 20.0)
	assert_eq(result["count"], 3)
	assert_eq(typeof(result["count"]), TYPE_INT)
	assert_eq(result["kind"], "kinetic")


func test_missing_optional_fields_get_defaults() -> void:
	var result: Dictionary = _check({"id": "a"})
	assert_eq(_report.error_count(), 0)
	assert_eq(result["hp"], 50)
	assert_eq(result["kind"], "energy")
	assert_eq(result["tags"], [])


func test_missing_required_field_is_an_error() -> void:
	_check({"hp": 20})
	assert_eq(_report.error_count(), 1)
	var issue: Dictionary = _report.get_issues()[0]
	assert_eq(issue["file"], "test.json")
	assert_eq(issue["field"], "id")
	assert_string_contains(issue["problem"], "required")


func test_wrong_type_is_reported_and_replaced_by_default() -> void:
	var result: Dictionary = _check({"id": "a", "hp": "lots"})
	assert_eq(_report.error_count(), 1)
	assert_eq(_report.get_issues()[0]["field"], "hp")
	assert_eq(result["hp"], 50)


func test_number_outside_range_is_an_error() -> void:
	_check({"id": "a", "hp": 0})
	_check({"id": "a", "hp": 5000})
	assert_eq(_report.error_count(), 2)


func test_int_must_be_whole() -> void:
	_check({"id": "a", "count": 2.5})
	assert_eq(_report.error_count(), 1)


func test_enum_rejects_unknown_value() -> void:
	var result: Dictionary = _check({"id": "a", "kind": "magic"})
	assert_eq(_report.error_count(), 1)
	assert_eq(result["kind"], "energy")


func test_unknown_field_is_a_warning_not_an_error() -> void:
	var result: Dictionary = _check({"id": "a", "hpp": 3, "_comment": "notes are fine"})
	assert_eq(_report.error_count(), 0)
	assert_eq(_report.warning_count(), 1)
	assert_false(result.has("hpp"))


func test_invalid_array_items_are_dropped() -> void:
	var result: Dictionary = _check({"id": "a", "tags": ["ok", 5, "fine"]})
	assert_eq(_report.error_count(), 1)
	assert_eq(_report.get_issues()[0]["field"], "tags[1]")
	assert_eq(result["tags"], ["ok", "fine"])


func test_non_object_input_does_not_crash() -> void:
	assert_null(_check("not an object"))
	assert_null(_check(null))
	assert_null(_check([1, 2]))
	assert_eq(_report.error_count(), 3)


func test_defaults_fill_nested_objects() -> void:
	var nested: Dictionary = {
		"type": "object",
		"fields": {
			"aim": {"type": "object", "required": true, "fields": {"yaw": {"type": "number", "default": 80}}},
		},
	}
	var result: Dictionary = DataSchema.defaults(nested)
	assert_eq(result["aim"]["yaw"], 80)
