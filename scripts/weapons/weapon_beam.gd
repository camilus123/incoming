extends Weapon
## Archetype "beam": a continuous ray while the trigger is held.
##
## `damage` is damage per second. `heat.per_shot` is heat per second of firing.
## Data block "beam":
##   ramp_time_s, ramp_max_multiplier   damage grows while the beam stays on one target
##   pierce                             extra targets the beam passes through (-1 = all)
##   chain_targets, chain_range_m       lightning that jumps on to nearby targets
##   width_m                            look of the beam
## Damage is applied in small ticks so hit feedback stays readable.

const TICK_S: float = 0.1
const MAX_PIERCE: int = 16

var _tick_s: float = 0.0
var _ramp_s: float = 0.0
var _ramp_target: CombatTarget
var _exclude: Array[RID] = []
var _struck: Array[Hurtbox] = []
var _chain: Array[CombatTarget] = []


func get_charge_fraction() -> float:
	var ramp_time_s: float = _block("beam").get("ramp_time_s", 0.0)
	return clampf(_ramp_s / ramp_time_s, 0.0, 1.0) if ramp_time_s > 0.0 else 0.0


func _update_weapon(delta_s: float) -> void:
	if not (trigger_held and heat.can_fire() and has_ammo()):
		_ramp_s = 0.0
		_ramp_target = null
		_tick_s = 0.0
		return
	var block: Dictionary = _block("beam")
	heat.add_heat(heat.per_shot * delta_s)

	# Trace the beam: the first target, then whatever it pierces.
	var end: Vector3 = _context.aim_origin + _context.aim_direction * float(data.get("range_m", 3000.0))
	_exclude.clear()
	_struck.clear()
	var pierce: int = int(block.get("pierce", 0))
	var limit: int = MAX_PIERCE if pierce < 0 else pierce + 1
	for step: int in limit:
		var hit: Dictionary = _cast_aim_ray(_context.aim_direction, _exclude)
		if hit.is_empty():
			break
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null:
			end = hit["position"]  # Terrain stops the beam.
			break
		_exclude.append(hit["rid"])
		var struck: Hurtbox = hurtbox.redirect(_context.aim_origin, _context.aim_direction, _context.aim_origin.distance_to(hit["position"]))
		# A big ship has several hit shapes; it must only be damaged once.
		var already: bool = false
		for other: Hurtbox in _struck:
			if other.target == struck.target:
				already = true
		if already:
			continue
		_struck.append(struck)
		if step == limit - 1:
			end = hit["position"]

	# The beam ramps up while it stays on the same first target.
	var first: CombatTarget = _struck[0].target if not _struck.is_empty() else null
	if first != null and first == _ramp_target:
		_ramp_s += delta_s
	else:
		_ramp_s = 0.0
		_ramp_target = first
	var ramp: float = lerpf(1.0, float(block.get("ramp_max_multiplier", 1.0)), get_charge_fraction())

	_find_chain(first, block)
	_tick_s += delta_s
	if _tick_s >= TICK_S:
		_tick_s -= TICK_S
		_damage_info.amount = float(data.get("damage", 0.0)) * TICK_S * ramp * get_damage_scale()
		_damage_info.armour_factor = TICK_S
		for hurtbox: Hurtbox in _struck:
			_damage_info.hit_position = hurtbox.global_position
			hurtbox.apply_hit(_damage_info)
		for target: CombatTarget in _chain:
			_damage_info.hit_position = target.get_aim_point()
			target.apply_damage(_damage_info)
		_spend_ammo()
		EventBus.weapon_fired.emit(slot)
		_context.rig.add_shake(_feel("shake", 0.0))

	_draw_beam(end, first, block, ramp)


## Finds the targets the lightning jumps to after the first one.
func _find_chain(first: CombatTarget, block: Dictionary) -> void:
	_chain.clear()
	var chain_targets: int = block.get("chain_targets", 0)
	if first == null or chain_targets <= 0:
		return
	var range_m: float = block.get("chain_range_m", 150.0)
	var from: CombatTarget = first
	var candidates: Array[Node] = get_tree().get_nodes_in_group(CombatTarget.GROUP)
	for jump: int in chain_targets:
		var best: CombatTarget = null
		var best_distance: float = range_m
		for node: Node in candidates:
			var target: CombatTarget = node as CombatTarget
			if target == null or target == first or _chain.has(target) or not target.is_alive():
				continue
			var distance: float = from.get_aim_point().distance_to(target.get_aim_point())
			if distance < best_distance:
				best_distance = distance
				best = target
		if best == null:
			break
		_chain.append(best)
		from = best


func _draw_beam(end: Vector3, first: CombatTarget, block: Dictionary, ramp: float) -> void:
	if _context.fx == null:
		return
	var width: float = float(block.get("width_m", 0.25)) * (0.7 + 0.3 * ramp)
	var intensity: float = 3.0 + ramp * get_damage_scale()
	var muzzle: Vector3 = _muzzle_position(0)
	# Redrawn every frame with a very short life, so it follows the aim exactly.
	_context.fx.tracer(muzzle, end, _tracer_color, width, 0.035, intensity)
	if _muzzles.size() > 1:
		_context.fx.tracer(_muzzle_position(1), end, _tracer_color, width, 0.035, intensity)
	if first != null:
		_context.fx.flash(end, 0.5, 0.5 + float(_visual("impact_radius_m", 2.0)) * 0.5, _tracer_color, 0.05, intensity)
		_context.fx.sparks(end, muzzle - end)
	var from: Vector3 = first.get_aim_point() if first != null else end
	for target: CombatTarget in _chain:
		var to: Vector3 = target.get_aim_point()
		# A kinked line reads as lightning.
		var middle: Vector3 = from.lerp(to, 0.5) + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * from.distance_to(to) * 0.08
		_context.fx.tracer(from, middle, _tracer_color, width * 0.7, 0.05, intensity)
		_context.fx.tracer(middle, to, _tracer_color, width * 0.7, 0.05, intensity)
		from = to
