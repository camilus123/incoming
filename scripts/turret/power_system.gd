class_name PowerSystem
extends RefCounted
## The reactor's power split between shields and weapons (spec 3.4).
##
## One value, `shield_share`, from 0 to 1 in fixed steps;
## `weapon_share = 1 - shield_share`. Both multipliers are linear in their
## share. Pure maths, unit tested; all numbers come from power.json.

var shield_share: float = 0.5
var default_share: float = 0.5
var step: float = 0.1
var min_share: float = 0.0
var max_share: float = 1.0
var shield_recharge_at_zero: float = 0.0
var shield_recharge_at_full: float = 2.0
var weapon_output_at_zero: float = 0.5
var weapon_output_at_full: float = 1.5
## Reactor upgrades raise the top end of both curves: 0.1 = +10 %.
var reactor_bonus: float = 0.0


## Reads the "power" config. The current split is kept unless `reset_share`.
func configure(power_config: Dictionary, reset_share: bool = true) -> void:
	var share: Dictionary = power_config.get("shield_share", {})
	default_share = share.get("default", 0.5)
	step = share.get("step", 0.1)
	min_share = share.get("min", 0.0)
	max_share = share.get("max", 1.0)
	var recharge: Dictionary = power_config.get("shield_recharge_multiplier", {})
	shield_recharge_at_zero = recharge.get("at_zero_share", 0.0)
	shield_recharge_at_full = recharge.get("at_full_share", 2.0)
	var output: Dictionary = power_config.get("weapon_output_multiplier", {})
	weapon_output_at_zero = output.get("at_zero_share", 0.5)
	weapon_output_at_full = output.get("at_full_share", 1.5)
	shield_share = default_share if reset_share else clampf(shield_share, min_share, max_share)


func get_weapon_share() -> float:
	return 1.0 - shield_share


## Moves one step towards weapons. Returns true if the split changed.
func shift_to_weapons() -> bool:
	return _set_share(shield_share - step)


## Moves one step towards shields. Returns true if the split changed.
func shift_to_shields() -> bool:
	return _set_share(shield_share + step)


## Back to the default split. Returns true if the split changed.
func reset() -> bool:
	return _set_share(default_share)


## Multiplier on the shield recharge rate. At a shield share of 0 this is
## `at_zero_share` (0 by default: the shield holds its charge but does not refill).
func shield_recharge_multiplier() -> float:
	return lerpf(shield_recharge_at_zero, shield_recharge_at_full * (1.0 + reactor_bonus), shield_share)


## Multiplier on weapon output: damage for energy weapons, fire rate and
## cooling for kinetic weapons.
func weapon_output_multiplier() -> float:
	return lerpf(weapon_output_at_zero, weapon_output_at_full * (1.0 + reactor_bonus), get_weapon_share())


func _set_share(value: float) -> bool:
	# Snap to the step grid so repeated steps never drift (0.1 * 3 != 0.3 in floats).
	var snapped_value: float = clampf(snappedf(value, 0.0001), min_share, max_share)
	if is_equal_approx(snapped_value, shield_share):
		return false
	shield_share = snapped_value
	return true
