extends Weapon
## Archetype "area_pulse": launches a shell that releases a pulse where it
## lands (EMP Burst). The shell flies like a projectile ("projectile" block);
## the pulse is described by the "area_pulse" block:
##   radius_m, strip_shields, stun_s, stun_tags, cooldown_s

var _cooldown_s: float = 0.0


func get_reload_fraction() -> float:
	var cooldown_s: float = _block("area_pulse").get("cooldown_s", 0.0)
	return clampf(_cooldown_s / cooldown_s, 0.0, 1.0) if cooldown_s > 0.0 else 0.0


func _update_weapon(delta_s: float) -> void:
	_cooldown_s = maxf(0.0, _cooldown_s - delta_s)
	if not (trigger_held and _cooldown_s <= 0.0 and heat.can_fire() and has_ammo()):
		return
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.projectiles != null:
		_context.projectiles.fire(muzzle, _aim_direction_from(muzzle), data, slot, float(data.get("damage", 0.0)) * get_damage_scale(), "emp")
	if _context.fx != null:
		_context.fx.flash(muzzle, 0.1, 0.7, _tracer_color, 0.1, 6.0)
	_spend_ammo()
	_apply_shot_feedback()
	_cooldown_s = _block("area_pulse").get("cooldown_s", 6.0)
