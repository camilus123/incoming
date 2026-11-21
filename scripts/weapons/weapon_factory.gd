class_name WeaponFactory
extends RefCounted
## Creates the right weapon script for a weapon data file.
##
## A new weapon that uses an existing archetype needs no code: its JSON names
## the archetype. A new archetype is one script plus one line here.

const ARCHETYPES: Dictionary = {
	"hitscan_pulse": preload("res://scripts/weapons/weapon_hitscan_pulse.gd"),
	"homing": preload("res://scripts/weapons/weapon_homing.gd"),
}


## True if the archetype has an implementation yet.
static func supports(archetype: String) -> bool:
	return ARCHETYPES.has(archetype)


## Returns a new, not yet set-up weapon for `weapon_data`, or null if its
## archetype is not implemented.
static func create(weapon_data: Dictionary) -> Weapon:
	var archetype: String = weapon_data.get("archetype", "")
	if not ARCHETYPES.has(archetype):
		push_warning("Weapon \"%s\": archetype \"%s\" is not implemented yet" % [weapon_data.get("id", "?"), archetype])
		return null
	var script: GDScript = ARCHETYPES[archetype]
	return script.new() as Weapon
