extends Weapon
## Archetypes "projectile" and "airburst": shots with travel time, launched
## from the muzzles and simulated by the [ProjectileSystem].
##
## Data block "projectile":
##   speed_mps, lifetime_s, gravity_mps2, drag     flight
##   splash_radius_m                               blast on impact (0 = none)
##   proximity_fuse_m                              airburst: detonate near a target
##   pellets, cone_deg                             several shots per trigger pull
##   pierce                                        targets a slug passes through
##   size_m, length_m                              look of the bolt
##   on_detonate                                   "", "emp" or "singularity"

const MAX_SHOTS_PER_FRAME: int = 4

var _cooldown_s: float = 0.0


func _update_weapon(delta_s: float) -> void:
	_cooldown_s -= delta_s
	if not (trigger_held and heat.can_fire() and has_ammo()):
		_cooldown_s = maxf(_cooldown_s, 0.0)
		return
	var interval_s: float = 1.0 / (float(data.get("fire_rate", 1.0)) * get_rate_scale())
	var shots: int = 0
	while _cooldown_s <= 0.0 and shots < MAX_SHOTS_PER_FRAME and heat.can_fire() and has_ammo():
		_fire()
		_cooldown_s += interval_s
		shots += 1
	_cooldown_s = maxf(_cooldown_s, 0.0)


func _fire() -> void:
	var block: Dictionary = _block("projectile")
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	var direction: Vector3 = _aim_direction_from(muzzle)
	var spread_deg: float = maxf(float(data.get("spread_deg", 0.0)), float(block.get("cone_deg", 0.0)))
	var damage: float = float(data.get("damage", 0.0)) * get_damage_scale()
	if _context.projectiles != null:
		for pellet: int in int(block.get("pellets", 1)):
			_context.projectiles.fire(muzzle, _spread(direction, spread_deg), data, slot, damage, block.get("on_detonate", ""))
	if _context.fx != null:
		_context.fx.flash(muzzle, 0.08, 0.2 + float(block.get("size_m", 0.3)), _tracer_color, 0.06, 6.0)
	_spend_ammo()
	_apply_shot_feedback()
