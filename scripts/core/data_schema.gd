class_name DataSchema
extends RefCounted
## Checks a parsed JSON value against a simple schema and returns a cleaned copy.
##
## The schema format is documented in docs/DATA_FORMAT.md. In short, a schema
## is a dictionary with a "type" ("string", "number", "int", "bool", "array",
## "object", "dict" or "any") plus type-specific options ("min", "max", "enum",
## "items", "fields", "values", "default", "required", ...).
##
## Nothing here throws: every problem is added to the [DataReport] and the
## offending value is replaced by its default (if the schema has one) or dropped.


## Validates `value` against `schema`.
## Returns the cleaned value, or null if the value itself is unusable.
## `file` and `path` are only used for error messages.
static func validate(value: Variant, schema: Dictionary, file: String, report: DataReport, path: String = "") -> Variant:
	var type_name: String = str(schema.get("type", "any"))
	match type_name:
		"any":
			return value
		"string":
			return _validate_string(value, schema, file, report, path)
		"number":
			return _validate_number(value, schema, false, file, report, path)
		"int":
			return _validate_number(value, schema, true, file, report, path)
		"bool":
			if value is bool:
				return value
			_type_error("true or false", value, file, report, path)
			return null
		"array":
			return _validate_array(value, schema, file, report, path)
		"object":
			return _validate_object(value, schema, file, report, path)
		"dict":
			return _validate_dict(value, schema, file, report, path)
		_:
			report.add_error(file, path, "schema uses unknown type '%s'" % type_name)
			return null


## Returns the value a schema produces for empty input, i.e. all its defaults.
## Used as the fallback when a config file is missing or unreadable.
static func defaults(schema: Dictionary) -> Variant:
	var scratch: DataReport = DataReport.new()
	return validate({}, schema, "", scratch)


static func _validate_string(value: Variant, schema: Dictionary, file: String, report: DataReport, path: String) -> Variant:
	if not value is String:
		_type_error("a string", value, file, report, path)
		return null
	var text: String = value
	if schema.get("non_empty", false) and text.is_empty():
		report.add_error(file, path, "must not be empty")
		return null
	if schema.has("enum"):
		var allowed: Array = schema["enum"]
		if not allowed.has(text):
			report.add_error(file, path, "must be one of %s (got \"%s\")" % [JSON.stringify(allowed), text])
			return null
	return text


static func _validate_number(value: Variant, schema: Dictionary, whole: bool, file: String, report: DataReport, path: String) -> Variant:
	if not (value is float or value is int):
		_type_error("a whole number" if whole else "a number", value, file, report, path)
		return null
	var number: float = float(value)
	if whole and not is_equal_approx(number, roundf(number)):
		report.add_error(file, path, "must be a whole number (got %s)" % _number_text(number))
		return null
	if schema.has("min") and number < float(schema["min"]):
		report.add_error(file, path, "must be >= %s (got %s)" % [_number_text(float(schema["min"])), _number_text(number)])
		return null
	if schema.has("max") and number > float(schema["max"]):
		report.add_error(file, path, "must be <= %s (got %s)" % [_number_text(float(schema["max"])), _number_text(number)])
		return null
	if whole:
		return int(roundf(number))
	return number


static func _validate_array(value: Variant, schema: Dictionary, file: String, report: DataReport, path: String) -> Variant:
	if not value is Array:
		_type_error("an array", value, file, report, path)
		return null
	var source: Array = value
	var item_schema: Dictionary = schema.get("items", {"type": "any"})
	var result: Array = []
	for index: int in source.size():
		var errors_before: int = report.error_count()
		var checked: Variant = validate(source[index], item_schema, file, report, "%s[%d]" % [path, index])
		# Items with any problem are dropped; the errors are already reported.
		if report.error_count() == errors_before:
			result.append(checked)
	if schema.has("min_items") and result.size() < int(schema["min_items"]):
		report.add_error(file, path, "needs at least %d valid item(s) (has %d)" % [int(schema["min_items"]), result.size()])
		return null
	return result


static func _validate_object(value: Variant, schema: Dictionary, file: String, report: DataReport, path: String) -> Variant:
	if not value is Dictionary:
		_type_error("an object", value, file, report, path)
		return null
	var source: Dictionary = value
	var fields: Dictionary = schema.get("fields", {})
	var result: Dictionary = {}
	for key: String in fields:
		var field_schema: Dictionary = fields[key]
		var field_path: String = _join(path, key)
		var is_any: bool = str(field_schema.get("type", "any")) == "any"
		if source.has(key):
			var checked: Variant = validate(source[key], field_schema, file, report, field_path)
			if checked != null or is_any:
				result[key] = checked
			elif field_schema.has("default"):
				result[key] = _copy(field_schema["default"])
			elif str(field_schema.get("type")) == "object":
				result[key] = defaults(field_schema)
		elif field_schema.has("default"):
			result[key] = _copy(field_schema["default"])
		elif field_schema.get("required", false):
			report.add_error(file, field_path, "required field is missing")
			if str(field_schema.get("type")) == "object":
				result[key] = defaults(field_schema)
	for key: Variant in source:
		var key_text: String = str(key)
		if fields.has(key_text) or key_text.begins_with("_"):
			continue  # Known field, or a "_comment"-style note.
		if schema.get("allow_unknown", false):
			result[key_text] = source[key]
		else:
			report.add_warning(file, _join(path, key_text), "unknown field (ignored); check for a typo")
	return result


static func _validate_dict(value: Variant, schema: Dictionary, file: String, report: DataReport, path: String) -> Variant:
	if not value is Dictionary:
		_type_error("an object", value, file, report, path)
		return null
	var source: Dictionary = value
	var value_schema: Dictionary = schema.get("values", {"type": "any"})
	var result: Dictionary = {}
	for key: Variant in source:
		var key_text: String = str(key)
		if key_text.begins_with("_"):
			continue
		var errors_before: int = report.error_count()
		var checked: Variant = validate(source[key], value_schema, file, report, _join(path, key_text))
		if report.error_count() == errors_before:
			result[key_text] = checked
	if schema.has("required_keys"):
		for required_key: String in schema["required_keys"]:
			if not result.has(required_key):
				report.add_error(file, _join(path, required_key), "required entry is missing or invalid")
	return result


static func _type_error(expected: String, value: Variant, file: String, report: DataReport, path: String) -> void:
	report.add_error(file, path, "expected %s, got %s" % [expected, _describe(value)])


static func _describe(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return "a string"
	if value is bool:
		return "true/false"
	if value is float or value is int:
		return "a number"
	if value is Array:
		return "an array"
	if value is Dictionary:
		return "an object"
	return type_string(typeof(value))


static func _number_text(number: float) -> String:
	return String.num(number, 4)


static func _join(path: String, key: String) -> String:
	return key if path.is_empty() else path + "." + key


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
