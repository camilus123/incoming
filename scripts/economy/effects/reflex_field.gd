extends SpecialEffect
## "reflex_field" (Flicker IV). The shield recharges faster for a short time
## after it breaks.
## Parameters: multiplier, duration_s.

var _left_s: float = 0.0


func on_stage_start() -> void:
	_left_s = 0.0
	turret.shield.bonus_recharge_multiplier = 1.0


func on_shield_broken() -> void:
	_left_s = _param("duration_s", 2.0)
	turret.shield.bonus_recharge_multiplier = _param("multiplier", 2.0)


func tick(delta_s: float) -> void:
	if _left_s <= 0.0:
		return
	_left_s -= delta_s
	if _left_s <= 0.0:
		turret.shield.bonus_recharge_multiplier = 1.0
