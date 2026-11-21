class_name ShieldState
extends RefCounted
## Charge state of the turret's shield (spec 3.6). Pure logic, unit tested.
##
## The shield absorbs damage before the hull. After `recharge_delay_s` without
## a hit it refills at `recharge_per_s` times the power split's multiplier.

var capacity: float = 100.0
var charge: float = 100.0
var recharge_per_s: float = 12.0
var recharge_delay_s: float = 3.0
## Share of the base recharge that always applies, whatever the power split
## (Bastion IV: 0.25). 0 = none.
var min_recharge_multiplier: float = 0.0

var _time_since_hit_s: float = 0.0
var _was_empty: bool = false


## Reads a shield data file. The shield starts fully charged.
func configure(shield_data: Dictionary) -> void:
	capacity = shield_data.get("capacity", 0.0)
	recharge_per_s = shield_data.get("recharge_per_s", 0.0)
	recharge_delay_s = shield_data.get("recharge_delay_s", 3.0)
	refill()


func refill() -> void:
	charge = capacity
	_time_since_hit_s = recharge_delay_s
	_was_empty = false


## Charge as a fraction of capacity, 0 to 1.
func get_fraction() -> float:
	return charge / capacity if capacity > 0.0 else 0.0


func is_up() -> bool:
	return charge > 0.0


## Absorbs as much of `amount` as the charge allows and returns the damage
## that got through to the hull.
func absorb(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	_time_since_hit_s = 0.0
	var absorbed: float = minf(amount, charge)
	charge -= absorbed
	return amount - absorbed


## Recharges. Returns +1 when the shield just came back from empty to full,
## -1 when it has just been emptied, otherwise 0.
func tick(delta_s: float, recharge_multiplier: float) -> int:
	var event: int = 0
	if charge <= 0.0 and not _was_empty and capacity > 0.0:
		_was_empty = true
		event = -1
	_time_since_hit_s += delta_s
	var multiplier: float = maxf(recharge_multiplier, min_recharge_multiplier)
	if charge < capacity and _time_since_hit_s >= recharge_delay_s and multiplier > 0.0:
		charge = minf(capacity, charge + recharge_per_s * multiplier * delta_s)
		if _was_empty and charge >= capacity:
			_was_empty = false
			event = 1
	return event
