extends SpecialEffect
## "damage_reduction_while_shielded" (Bastion III: Hardened Matrix).
## All incoming damage is reduced while the shield is above a threshold.
## Parameters: reduction (0..1), min_shield_fraction (0..1).


func modify_incoming_damage(amount: float, _damage_type: String) -> float:
	if turret.shield.get_fraction() > _param("min_shield_fraction", 0.5):
		return amount * (1.0 - clampf(_param("reduction", 0.15), 0.0, 1.0))
	return amount
