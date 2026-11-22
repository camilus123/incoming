class_name Modifiers
extends RefCounted
## Generic stat modifiers from tech tree nodes. Pure logic, unit tested.
##
## A modifier is `{ "target": "shield.capacity", "op": "set", "value": 180 }`.
## The target is a dotted path: a scope ("shield", "weapon.<id>", "turret",
## "power", "hud") followed by the field inside that scope's data. `*` matches
## any one segment, so "weapon.*.heat.per_shot" applies to every weapon.
##
## Stacking rule, independent of the order of purchase except for "set":
##   value = (last "set", or the base value) + sum of "add"s, times all "mul"s.

const OPS: PackedStringArray = ["set", "add", "mul"]
const SCOPES: PackedStringArray = ["shield", "weapon", "turret", "power", "hud"]


## Collects the modifier effects of the given tree nodes, in order.
static func from_nodes(nodes: Array[Dictionary]) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	for tree_node: Dictionary in nodes:
		for effect: Dictionary in tree_node.get("effects", []):
			if effect.has("target"):
				modifiers.append(effect)
	return modifiers


## If `target` addresses something inside `scope`, returns the path of the
## field within the scope; otherwise "".
## Example: ("weapon.*.heat.per_shot", "weapon.pulse_laser") -> "heat.per_shot".
static func match_scope(target: String, scope: String) -> String:
	var target_parts: PackedStringArray = target.split(".")
	var scope_parts: PackedStringArray = scope.split(".")
	if target_parts.size() <= scope_parts.size():
		return ""
	for index: int in scope_parts.size():
		if target_parts[index] != "*" and target_parts[index] != scope_parts[index]:
			return ""
	return ".".join(target_parts.slice(scope_parts.size()))


## Returns a deep copy of `base` with every modifier that targets `scope` applied.
static func apply(base: Dictionary, scope: String, modifiers: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	# Gather what happens to each field first, so stacking does not depend on order.
	var changes: Dictionary = {}  # path -> { has_set, set, add, mul }
	for modifier: Dictionary in modifiers:
		var path: String = match_scope(str(modifier.get("target", "")), scope)
		if path.is_empty():
			continue
		var change: Dictionary = changes.get_or_add(path, {"has_set": false, "set": null, "add": 0.0, "mul": 1.0})
		match str(modifier.get("op", "")):
			"set":
				change["has_set"] = true
				change["set"] = modifier.get("value")
			"add":
				change["add"] += float(modifier.get("value", 0.0))
			"mul":
				change["mul"] *= float(modifier.get("value", 1.0))

	for path: String in changes:
		var change: Dictionary = changes[path]
		var original: Variant = get_path_value(result, path, null)
		var value: Variant = change["set"] if change["has_set"] else original
		var has_maths: bool = change["add"] != 0.0 or change["mul"] != 1.0
		if has_maths:
			var number: float = float(value) if (value is float or value is int) else 0.0
			number = (number + float(change["add"])) * float(change["mul"])
			# Whole-number stats (salvo size, ammo) stay whole numbers.
			value = int(roundf(number)) if original is int and is_equal_approx(number, roundf(number)) else number
		if change["has_set"] or has_maths:
			set_path_value(result, path, value)
	return result


## Reads `data["a"]["b"]` for the path "a.b"; `fallback` if any part is missing.
static func get_path_value(data: Dictionary, path: String, fallback: Variant) -> Variant:
	var current: Variant = data
	for part: String in path.split("."):
		if not current is Dictionary or not (current as Dictionary).has(part):
			return fallback
		current = current[part]
	return current


## Writes `data["a"]["b"] = value` for the path "a.b", creating objects on the way.
static func set_path_value(data: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var current: Dictionary = data
	for index: int in parts.size() - 1:
		if not current.get(parts[index]) is Dictionary:
			current[parts[index]] = {}
		current = current[parts[index]]
	current[parts[parts.size() - 1]] = value
