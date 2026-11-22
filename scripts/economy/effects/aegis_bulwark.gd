extends SpecialEffect
## "aegis_bulwark" (Bastion capstone). Once per stage a hit that would
## destroy the turret is absorbed completely and the shield is restored.
## Parameters: restore_fraction (0..1 of shield capacity).

var _used_this_stage: bool = false


func on_stage_start() -> void:
	_used_this_stage = false


func absorb_lethal_hit() -> bool:
	if _used_this_stage:
		return false
	_used_this_stage = true
	turret.shield.charge = turret.shield.capacity * clampf(_param("restore_fraction", 0.5), 0.0, 1.0)
	turret.flash_shield(1.0)
	EventBus.ui_message.emit("AEGIS BULWARK")
	return true
