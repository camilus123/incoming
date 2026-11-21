class_name HeatModel
extends RefCounted
## Heat meter of one weapon, from 0 (cold) to 1 (overheated).
##
## Each shot adds heat. After a short delay without firing the weapon cools.
## Reaching 1 locks the weapon until it has cooled down to `overheat_unlock`.

var heat: float = 0.0
var overheated: bool = false

var per_shot: float = 0.05
var cooling_per_s: float = 0.3
var cooling_delay_s: float = 0.3
var overheat_unlock: float = 0.35

var _time_since_heat: float = 0.0


## Reads the "heat" block of a weapon file.
func configure(heat_config: Dictionary) -> void:
	per_shot = heat_config.get("per_shot", per_shot)
	cooling_per_s = heat_config.get("cooling_per_s", cooling_per_s)
	cooling_delay_s = heat_config.get("cooling_delay_s", cooling_delay_s)
	overheat_unlock = heat_config.get("overheat_unlock", overheat_unlock)


## Adds the heat of one shot (or a custom amount). `heat_multiplier` is for
## upgrades such as Fast Cooling. Returns true if this caused an overheat.
func add_shot(heat_multiplier: float = 1.0) -> bool:
	return add_heat(per_shot * heat_multiplier)


func add_heat(amount: float) -> bool:
	_time_since_heat = 0.0
	heat = minf(1.0, heat + amount)
	if heat >= 1.0 and not overheated:
		overheated = true
		return true
	return false


## Cools the weapon. `cooling_multiplier` scales the cooling rate (power split).
func tick(delta_s: float, cooling_multiplier: float = 1.0) -> void:
	_time_since_heat += delta_s
	if overheated or _time_since_heat >= cooling_delay_s:
		heat = maxf(0.0, heat - cooling_per_s * cooling_multiplier * delta_s)
	if overheated and heat <= overheat_unlock:
		overheated = false


func can_fire() -> bool:
	return not overheated
