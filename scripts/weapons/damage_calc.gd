class_name DamageCalc
extends RefCounted
## Damage rules (docs/DECISIONS.md 12 and 13). Pure maths, unit tested.
##
## 1. Shield: absorbs the hit first. Damage against the shield is multiplied
##    per damage type (energy 2x, kinetic 0.5x, explosive 1x by default).
##    If the shield breaks, the unused share of the hit carries on to the hull.
## 2. Armour: a flat amount is removed from the hit, reduced by the weapon's
##    armour pierce. A hit always keeps at least `armour_min_damage_fraction`.
## 3. Resistance: the remaining damage is reduced by the target's resistance
##    to that damage type.


## Applies one hit to `stats` and returns what happened.
## `rules` is the "combat" config.
static func apply(amount: float, damage_type: String, armour_pierce: float, stats: TargetStats, rules: Dictionary) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	if amount <= 0.0 or stats.is_dead():
		return result
	stats.note_hit()

	var remaining: float = amount
	if stats.shield > 0.0:
		var multipliers: Dictionary = rules.get("shield_damage_multipliers", {})
		var shield_multiplier: float = multipliers.get(damage_type, 1.0)
		var shield_hit: float = amount * shield_multiplier
		if shield_hit < stats.shield:
			stats.shield -= shield_hit
			result.shield_damage = shield_hit
			return result
		# The shield breaks; the share of the hit it could not absorb goes on.
		result.shield_damage = stats.shield
		result.shield_broken = true
		remaining = amount * (1.0 - stats.shield / shield_hit) if shield_hit > 0.0 else amount
		stats.shield = 0.0
		if remaining <= 0.0:
			return result

	var effective_armour: float = maxf(0.0, stats.armour - armour_pierce)
	var min_fraction: float = rules.get("armour_min_damage_fraction", 0.1)
	var after_armour: float = maxf(remaining - effective_armour, remaining * min_fraction)
	var resistance: float = clampf(stats.resistances.get(damage_type, 0.0), 0.0, 1.0)
	var hull_hit: float = minf(after_armour * (1.0 - resistance), stats.hp)

	stats.hp -= hull_hit
	result.hull_damage = hull_hit
	result.killed = stats.hp <= 0.0
	return result


## Damage multiplier for a splash hit at `distance_m` from the centre of an
## explosion with `radius_m`: 1 at the centre, `edge_fraction` at the edge,
## 0 outside.
static func splash_falloff(distance_m: float, radius_m: float, edge_fraction: float) -> float:
	if radius_m <= 0.0 or distance_m > radius_m:
		return 0.0
	return lerpf(1.0, edge_fraction, clampf(distance_m / radius_m, 0.0, 1.0))


## Hit radius of a target seen from `distance_m`, with the distance assist:
## far targets never look smaller than `min_angular_radius_deg`, but the
## radius grows to at most `max_scale` times the real one.
## `assist` is the "hitbox_assist" block of the combat config.
static func assisted_radius(base_radius_m: float, distance_m: float, assist: Dictionary) -> float:
	var min_angle: float = deg_to_rad(assist.get("min_angular_radius_deg", 0.0))
	var wanted: float = distance_m * tan(min_angle)
	return clampf(wanted, base_radius_m, base_radius_m * float(assist.get("max_scale", 1.0)))