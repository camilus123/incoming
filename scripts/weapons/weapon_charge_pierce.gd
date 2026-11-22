extends Weapon
## Archetype "charge_pierce": hold the trigger to charge, release to fire an
## instant shot that passes through several targets (Railgun).
##
## Data block "charge":
##   charge_time_s          time to a full charge
##   min_charge_fraction    below this a release does nothing
##   max_pierce             targets hit (-1 = everything on the line)
##   cooldown_s             pause after a shot
##   trail                  optional { duration_s, dps, radius_m }: lingering damage along the shot
## Damage scales with the charge reached.

const MAX_PIERCE: int = 32

var _charge: float = 0.0
var _cooldown_s: float = 0.0
var _was_held: bool = false
var _exclude: Array[RID] = []
var _hit_targets: Array[CombatTarget] = []


func get_charge_fraction() -> float:
	return _charge


func get_reload_fraction() -> float:
	var cooldown_s: float = _block("charge").get("cooldown_s", 0.0)
	return clampf(_cooldown_s / cooldown_s, 0.0, 1.0) if cooldown_s > 0.0 else 0.0


func _update_weapon(delta_s: float) -> void:
	var block: Dictionary = _block("charge")
	_cooldown_s = maxf(0.0, _cooldown_s - delta_s)
	var ready: bool = _cooldown_s <= 0.0 and heat.can_fire() and has_ammo()
	if trigger_held and ready:
		# Kinetic weapons charge faster with more reactor power.
		_charge = minf(1.0, _charge + delta_s * get_rate_scale() / maxf(float(block.get("charge_time_s", 0.8)), 0.01))
	elif _was_held and not trigger_held and ready and _charge >= float(block.get("min_charge_fraction", 0.35)):
		_fire(block)
	if not trigger_held:
		_charge = 0.0
	_was_held = trigger_held


func _fire(block: Dictionary) -> void:
	var direction: Vector3 = _context.aim_direction
	var end: Vector3 = _context.aim_origin + direction * float(data.get("range_m", 6000.0))
	var max_pierce: int = int(block.get("max_pierce", 1))
	var limit: int = MAX_PIERCE if max_pierce < 0 else maxi(1, max_pierce)
	_damage_info.amount = float(data.get("damage", 0.0)) * _charge * get_damage_scale()
	_exclude.clear()
	_hit_targets.clear()
	for step: int in limit * 4:
		if _hit_targets.size() >= limit:
			break
		var hit: Dictionary = _cast_aim_ray(direction, _exclude)
		if hit.is_empty():
			break
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null:
			end = hit["position"]  # Terrain stops the slug.
			break
		_exclude.append(hit["rid"])
		var struck: Hurtbox = hurtbox.redirect(_context.aim_origin, direction, _context.aim_origin.distance_to(hit["position"]))
		# A big ship has several hit shapes; it must only be damaged once.
		if _hit_targets.has(struck.target):
			continue
		_hit_targets.append(struck.target)
		_damage_info.hit_position = hit["position"]
		struck.apply_hit(_damage_info)
		if _context.fx != null:
			_context.fx.flash(hit["position"], 0.5, _visual("impact_radius_m", 3.0), _tracer_color, 0.15, 6.0)
			_context.fx.sparks(hit["position"], -direction)
		if _hit_targets.size() >= limit:
			end = hit["position"]

	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.fx != null:
		_context.fx.tracer(muzzle, end, _tracer_color, _visual("tracer_width_m", 0.3), _visual("tracer_life_s", 0.25), 7.0)
		_context.fx.flash(muzzle, 0.15, 0.8, _tracer_color, 0.1, 7.0)
	var trail: Dictionary = block.get("trail", {})
	if not trail.is_empty() and _context.projectiles != null:
		_context.projectiles.add_trail(_context.aim_origin + direction * 30.0, end, trail, data, slot, _tracer_color)

	_spend_ammo()
	_apply_shot_feedback()
	_cooldown_s = block.get("cooldown_s", 0.4)
	_charge = 0.0
