class_name DamageInfo
extends RefCounted
## One hit on a target: how much damage, of which type, from which weapon slot.
## Weapons keep one instance and reuse it for every shot.

var amount: float = 0.0
## "energy", "kinetic" or "explosive".
var damage_type: String = "energy"
## Points of the target's armour this hit ignores.
var armour_pierce: float = 0.0
## "primary" or "alternate" (empty for non-player damage).
var source_slot: StringName = &""
var hit_position: Vector3 = Vector3.ZERO


## Fills the fields that come straight from a weapon data file.
func configure_from_weapon(weapon_data: Dictionary, slot: StringName) -> void:
	amount = weapon_data.get("damage", 0.0)
	damage_type = weapon_data.get("damage_type", "energy")
	armour_pierce = weapon_data.get("armour_pierce", 0.0)
	source_slot = slot
