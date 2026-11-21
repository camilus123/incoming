class_name InputSetup
extends RefCounted
## Builds the InputMap from data/config/input.json.
##
## Actions are created from data so the settings menu can rebind them later
## without any action being hard-coded in project.godot.

const MOUSE_BUTTONS: Dictionary = {
	"left": MOUSE_BUTTON_LEFT,
	"right": MOUSE_BUTTON_RIGHT,
	"middle": MOUSE_BUTTON_MIDDLE,
	"wheel_up": MOUSE_BUTTON_WHEEL_UP,
	"wheel_down": MOUSE_BUTTON_WHEEL_DOWN,
	"extra1": MOUSE_BUTTON_XBUTTON1,
	"extra2": MOUSE_BUTTON_XBUTTON2,
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
		var action_data: Dictionary = actions[action_name]
		for event_data: Dictionary in action_data.get("events", []):
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
