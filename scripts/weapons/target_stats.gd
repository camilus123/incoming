class_name TargetStats
extends RefCounted
## Health state of anything that can be shot: hp, armour, shield, resistances.
## Pure data plus shield regeneration; no scene dependencies.

var max_hp: float = 100.0
var hp: float = 100.0
## Flat damage removed from every hit that reaches the hull.
var armour: float = 0.0
var max_shield: float = 0.0
var shield: float = 0.0
var shield_regen_per_s: float = 0.0
var shield_regen_delay_s: float = 3.0
## Damage type -> fraction of hull damage ignored (0.2 = 20 % less damage).
var resistances: Dictionary = {}

var _time_since_hit: float = 0.0


## Builds stats from a data entry with the fields
## `hp, armour, shield, shield_regen_per_s, shield_regen_delay_s, resistances`.
static func from_data(data: Dictionary) -> TargetStats:
	var stats: TargetStats = TargetStats.new()
	stats.max_hp = data.get("hp", 100.0)
	stats.hp = stats.max_hp
	stats.armour = data.get("armour", 0.0)
	stats.max_shield = data.get("shield", 0.0)
	stats.shield = stats.max_shield
	stats.shield_regen_per_s = data.get("shield_regen_per_s", 0.0)
	stats.shield_regen_delay_s = data.get("shield_regen_delay_s", 3.0)
	stats.resistances = data.get("resistances", {})
	return stats


func is_dead() -> bool:
	return hp <= 0.0


## Called by [DamageCalc] whenever the target is hit; restarts the regen delay.
func note_hit() -> void:
	_time_since_hit = 0.0


## Regenerates the shield once the target has not been hit for the delay.
func tick(delta_s: float) -> void:
	_time_since_hit += delta_s
	if is_dead() or shield >= max_shield or shield_regen_per_s <= 0.0:
		return
	if _time_since_hit >= shield_regen_delay_s:
		shield = minf(max_shield, shield + shield_regen_per_s * delta_s)
