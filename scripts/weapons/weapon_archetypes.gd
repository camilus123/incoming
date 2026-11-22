class_name WeaponArchetypes
extends RefCounted
## Names of the weapon archetypes that have an implementation, and the data
## block each one needs.
##
## Kept free of dependencies so the data validator can use it from the
## command line. [WeaponFactory] maps these names to scripts; a unit test
## checks that the two lists match.

const IMPLEMENTED: PackedStringArray = [
	"hitscan_pulse", "homing", "projectile", "airburst", "beam", "spinup", "charge_pierce", "area_pulse",
]

## Archetype -> data blocks a weapon of that archetype must have.
const REQUIRED_BLOCKS: Dictionary = {
	"homing": ["homing"],
	"projectile": ["projectile"],
	"airburst": ["projectile"],
	"beam": ["beam"],
	"spinup": ["spinup"],
	"charge_pierce": ["charge"],
	"area_pulse": ["projectile", "area_pulse"],
}
