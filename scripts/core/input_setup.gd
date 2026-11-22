class_name InputSetup
extends RefCounted
## Builds the InputMap from data/config/input.json, with the player's own
## bindings (the settings menu) on top.
##
## Actions are created from data, so none is hard-coded in project.godot. A
## rebound action is stored in the settings file in the same format as the
## data file; actions the player never touched follow the data defaults.

const MOUSE_BUTTONS: Dictionary = {
	"left": MOUSE_BUTTON_LEFT,
	"right": MOUSE_BUTTON_RIGHT,
	"middle": MOUSE_BUTTON_MIDDLE,
	"wheel_up": MOUSE_BUTTON_WHEEL_UP,
	"wheel_down": MOUSE_BUTTON_WHEEL_DOWN,
	"extra1": MOUSE_BUTTON_XBUTTON1,
	"extra2": MOUSE_BUTTON_XBUTTON2,
}

const MOUSE_NAMES: Dictionary = {
	"left": "Left mouse",
	"right": "Right mouse",
	"middle": "Middle mouse",
	"wheel_up": "Wheel up",
	"wheel_down": "Wheel down",
	"extra1": "Mouse button 4",
	"extra2": "Mouse button 5",
}


## Creates or replaces every action listed in the "input" config.
static func apply(config: Dictionary) -> void:
	var actions: Dictionary = config.get("actions", {})
	for action_name: String in actions:
		var action: StringName = StringName(action_name)
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for event_data: Dictionary in events_of(action_name):
			var event: InputEvent = event_from_data(event_data)
			if event != null:
				InputMap.action_add_event(action, event)


## Converts one `{ "key": ... }` or `{ "mouse_button": ... }` entry to an
## InputEvent. Returns null if the entry is not usable.
static func event_from_data(event_data: Dictionary) -> InputEvent:
	if event_data.has("mouse_button"):
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTONS.get(event_data["mouse_button"], MOUSE_BUTTON_NONE)
		return button if button.button_index != MOUSE_BUTTON_NONE else null
	if event_data.has("key"):
		var keycode: Key = OS.find_keycode_from_string(event_data["key"])
		if keycode == KEY_NONE:
			return null
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = keycode
		return key
	return null


## The bindings in force for an action: the player's, else the data file's.
static func events_of(action_name: String) -> Array:
	var overrides: Dictionary = UserSettings.get_value(UserSettings.BINDINGS)
	if overrides.has(action_name):
		return overrides[action_name]
	var actions: Dictionary = GameData.loader.get_config("input").get("actions", {})
	return (actions.get(action_name, {}) as Dictionary).get("events", [])


## Gives an action new bindings (entries in the format of input.json) and
## takes the same keys or buttons away from every other action.
static func rebind(action_name: String, events: Array) -> void:
	var overrides: Dictionary = (UserSettings.get_value(UserSettings.BINDINGS) as Dictionary).duplicate(true)
	var actions: Dictionary = GameData.loader.get_config("input").get("actions", {})
	for other: String in actions:
		if other == action_name:
			continue
		var kept: Array = []
		for existing: Dictionary in events_of(other):
			if not events.has(existing):
				kept.append(existing)
		if kept.size() != events_of(other).size():
			overrides[other] = kept
	overrides[action_name] = events
	_store(overrides)


## Exchanges the bindings of two actions (wheel up and wheel down).
static func swap(first: String, second: String) -> void:
	var overrides: Dictionary = (UserSettings.get_value(UserSettings.BINDINGS) as Dictionary).duplicate(true)
	var first_events: Array = events_of(first)
	overrides[first] = events_of(second)
	overrides[second] = first_events
	_store(overrides)


## Back to the bindings of the data file.
static func reset_all() -> void:
	_store({})


## The bindings of an action as text, e.g. "Left mouse" or "Enter, Space".
static func describe(action_name: String) -> String:
	var parts: PackedStringArray = []
	for event_data: Dictionary in events_of(action_name):
		if event_data.has("mouse_button"):
			parts.append(str(MOUSE_NAMES.get(event_data["mouse_button"], event_data["mouse_button"])))
		elif event_data.has("key"):
			parts.append(str(event_data["key"]))
	return ", ".join(parts) if not parts.is_empty() else "not bound"


static func _store(overrides: Dictionary) -> void:
	UserSettings.set_value(UserSettings.BINDINGS, overrides)
	UserSettings.save_settings()
	apply(GameData.loader.get_config("input"))
