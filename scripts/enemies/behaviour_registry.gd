class_name BehaviourRegistry
extends RefCounted
## Creates behaviour modules by name. A new enemy that combines existing
## modules needs no code; a new module is one script plus one line here
## (and in [BehaviourModules]).

const MODULES: Dictionary = {
	"approach_kamikaze": preload("res://scripts/enemies/behaviours/approach_kamikaze.gd"),
	"strafe": preload("res://scripts/enemies/behaviours/strafe.gd"),
	"level_pass": preload("res://scripts/enemies/behaviours/level_pass.gd"),
	"hover_shoot": preload("res://scripts/enemies/behaviours/hover_shoot.gd"),
	"orbit_drop": preload("res://scripts/enemies/behaviours/orbit_drop.gd"),
	"spawn_children": preload("res://scripts/enemies/behaviours/spawn_children.gd"),
	"shield_allies": preload("res://scripts/enemies/behaviours/shield_allies.gd"),
	"phases": preload("res://scripts/enemies/behaviours/phases.gd"),
}


## Returns a new module for a behaviour data entry, or null if its module is
## not implemented.
static func create(behaviour_data: Dictionary) -> EnemyBehaviour:
	var module_name: String = behaviour_data.get("module", "")
	if not MODULES.has(module_name):
		push_warning("Behaviour \"%s\": module \"%s\" is not implemented" % [behaviour_data.get("id", "?"), module_name])
		return null
	var script: GDScript = MODULES[module_name]
	return script.new() as EnemyBehaviour
