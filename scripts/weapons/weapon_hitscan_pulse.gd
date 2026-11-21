extends Weapon
## Archetype "hitscan_pulse": instant-hit shots at a fixed rate with a visible
## bolt (Pulse Laser). The ray starts at the sighting position, so shots land
## exactly under the crosshair; the bolt is drawn from the muzzle.

const MAX_SHOTS_PER_FRAME: int = 4

var _cooldown_s: float = 0.0
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _setup_weapon() -> void:
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = Layers.PHYSICS_WORLD | Layers.PHYSICS_ENEMY | Layers.PHYSICS_ENEMY_PROJECTILE


func _update_weapon(delta_s: float) -> void:
	_cooldown_s -= delta_s
	if not (trigger_held and heat.can_fire() and has_ammo()):
		_cooldown_s = maxf(_cooldown_s, 0.0)
		return
	# Energy weapons keep their fire rate (scale 1); power changes their damage instead.
	var interval_s: float = 1.0 / (float(data.get("fire_rate", 1.0)) * get_rate_scale())
	var shots: int = 0
	while _cooldown_s <= 0.0 and shots < MAX_SHOTS_PER_FRAME and heat.can_fire() and has_ammo():
		_fire()
		_cooldown_s += interval_s
		shots += 1
	_cooldown_s = maxf(_cooldown_s, 0.0)


func _fire() -> void:
	var direction: Vector3 = _spread(_context.aim_direction, data.get("spread_deg", 0.0))
	var origin: Vector3 = _context.aim_origin
	var range_m: float = data.get("range_m", 5000.0)
	var end: Vector3 = origin + direction * range_m

	_ray.from = origin
	_ray.to = end
	var hit: Dictionary = _context.world.direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		end = hit["position"]
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox != null:
			_damage_info.amount = float(data.get("damage", 0.0)) * get_damage_scale()
			_damage_info.hit_position = end
			hurtbox.apply_hit(_damage_info)

	if ammo != UNLIMITED_AMMO:
		ammo -= 1
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.fx != null:
		# More power makes the bolt visibly brighter and thicker.
		var power: float = get_damage_scale()
		_context.fx.tracer(muzzle, end, _tracer_color, float(_visual("tracer_width_m", 0.1)) * (0.6 + 0.4 * power), _visual("tracer_life_s", 0.07), 4.0 * power)
		_context.fx.flash(muzzle, 0.05, 0.22, _tracer_color, 0.05, 6.0)
		if not hit.is_empty():
			_context.fx.flash(end, 0.3, _visual("impact_radius_m", 2.0), _tracer_color, 0.12, 5.0)
	_apply_shot_feedback()


## Returns `direction` deflected by a random angle of up to `spread_deg`.
func _spread(direction: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var deflected: Vector3 = direction.rotated(side, deg_to_rad(randf() * spread_deg))
	return deflected.rotated(direction, randf() * TAU)
