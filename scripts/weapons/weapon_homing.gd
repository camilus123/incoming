extends Weapon
## Archetype "homing": guided missiles fired in salvos. Three ways to use it,
## chosen in the "homing" data block:
##
## - Lock-on (default, Micro-Missile Pod): hold the trigger with the crosshair
##   near targets to collect locks, one every `lock_time_s`. Release to launch;
##   missiles are shared out between the locks, or fly straight without one.
## - `auto_distribute` (Swarm Missiles): press the trigger and the salvo spreads
##   itself over every target near the crosshair.
## - `player_guided` (Seeker Torpedo): press to launch one missile, then keep
##   the trigger held to steer it with the crosshair.
##
## Missiles use a per-stage ammo stock, not reactor power.

const STEER_LEAD_M: float = 250.0

var _locks: Array[CombatTarget] = []
var _lock_timer_s: float = 0.0
var _reload_left_s: float = 0.0
var _was_held: bool = false
## Targets of missiles waiting to leave the pod (null = unguided).
var _launch_queue: Array[CombatTarget] = []
var _launch_timer_s: float = 0.0
var _steered_missile: int = -1


func get_reload_fraction() -> float:
	var reload_s: float = _homing("reload_s", 6.0)
	return clampf(_reload_left_s / reload_s, 0.0, 1.0) if reload_s > 0.0 else 0.0


func get_lock_targets() -> Array[CombatTarget]:
	return _locks


func get_lock_progress() -> float:
	var lock_time_s: float = _homing("lock_time_s", 0.3)
	if not trigger_held or lock_time_s <= 0.0 or _locks.size() >= _salvo_size() or _uses_instant_launch():
		return 0.0
	return clampf(_lock_timer_s / lock_time_s, 0.0, 1.0)


func _update_weapon(delta_s: float) -> void:
	_reload_left_s = maxf(0.0, _reload_left_s - delta_s)
	_drop_dead_locks()
	var ready: bool = _reload_left_s <= 0.0 and _launch_queue.is_empty() and heat.can_fire() and has_ammo()

	if _uses_instant_launch():
		if trigger_held and not _was_held and ready:
			if _homing("auto_distribute", false):
				_locks = _collect_targets()
			_start_salvo()
		_steer_guided_missile()
	else:
		if trigger_held and ready:
			_update_locking(delta_s)
		elif _was_held and not trigger_held and ready:
			_start_salvo()
		if not trigger_held:
			_locks.clear()
			_lock_timer_s = 0.0
	_was_held = trigger_held

	_update_launching(delta_s)


func _uses_instant_launch() -> bool:
	return _homing("auto_distribute", false) or _homing("player_guided", false)


func _update_locking(delta_s: float) -> void:
	if _locks.size() >= _salvo_size():
		return
	_lock_timer_s += delta_s
	if _lock_timer_s < float(_homing("lock_time_s", 0.3)):
		return
	var candidate: CombatTarget = _find_lock_candidate()
	if candidate != null:
		_locks.append(candidate)
		_lock_timer_s = 0.0


## Picks the target closest to the crosshair inside the lock cone. Targets
## with fewer locks are preferred so a salvo spreads over a group.
func _find_lock_candidate() -> CombatTarget:
	var cone_cos: float = cos(deg_to_rad(_homing("lock_cone_deg", 7.0)))
	var range_m: float = data.get("range_m", 4000.0)
	var best: CombatTarget = null
	var best_score: float = -INF
	for node: Node in get_tree().get_nodes_in_group(CombatTarget.GROUP):
		var target: CombatTarget = node as CombatTarget
		if target == null or not target.is_alive():
			continue
		var to_target: Vector3 = target.get_aim_point() - _context.aim_origin
		var distance: float = to_target.length()
		if distance > range_m or distance < 1.0:
			continue
		var alignment: float = _context.aim_direction.dot(to_target / distance)
		if alignment < cone_cos:
			continue
		var score: float = alignment - float(_locks.count(target))
		if score > best_score:
			best_score = score
			best = target
	return best


## Every target inside the lock cone, nearest to the crosshair first
## (auto-distributing salvos).
func _collect_targets() -> Array[CombatTarget]:
	var cone_cos: float = cos(deg_to_rad(_homing("lock_cone_deg", 30.0)))
	var range_m: float = data.get("range_m", 4000.0)
	var found: Array[CombatTarget] = []
	var alignments: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(CombatTarget.GROUP):
		var target: CombatTarget = node as CombatTarget
		if target == null or not target.is_alive():
			continue
		var to_target: Vector3 = target.get_aim_point() - _context.aim_origin
		var distance: float = to_target.length()
		if distance > range_m or distance < 1.0:
			continue
		var alignment: float = _context.aim_direction.dot(to_target / distance)
		if alignment >= cone_cos:
			found.append(target)
			alignments[target] = alignment
	found.sort_custom(func(a: CombatTarget, b: CombatTarget) -> bool: return alignments[a] > alignments[b])
	if found.size() > _salvo_size():
		found.resize(_salvo_size())
	return found


func _start_salvo() -> void:
	var count: int = _salvo_size()
	for index: int in count:
		_launch_queue.append(_locks[index % _locks.size()] if not _locks.is_empty() else null)
	_launch_timer_s = 0.0
	_reload_left_s = _homing("reload_s", 6.0)
	_locks = []
	_lock_timer_s = 0.0


func _update_launching(delta_s: float) -> void:
	if _launch_queue.is_empty():
		return
	_launch_timer_s -= delta_s
	while _launch_timer_s <= 0.0 and not _launch_queue.is_empty():
		var queued: Variant = _launch_queue.pop_front()
		# The target may have been destroyed and freed while the missile waited.
		_launch(queued as CombatTarget if is_instance_valid(queued) else null)
		_launch_timer_s += maxf(float(_homing("launch_interval_s", 0.1)), 0.001)


func _launch(target: CombatTarget) -> void:
	_spend_ammo()
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.missiles != null:
		var direction: Vector3 = _spread(_context.aim_direction, _homing("launch_spread_deg", 0.0))
		var handle: int = _context.missiles.launch(muzzle, direction, target, data, slot)
		if _homing("player_guided", false):
			_steered_missile = handle
	if _context.fx != null:
		_context.fx.flash(muzzle, 0.1, 0.5, _tracer_color, 0.09, 5.0)
	_apply_shot_feedback()


## While the trigger stays held, the guided missile flies towards the point
## the crosshair is on (a little ahead of the missile, along the aim ray).
func _steer_guided_missile() -> void:
	if _steered_missile < 0 or _context.missiles == null:
		return
	if not _context.missiles.is_flying(_steered_missile):
		_steered_missile = -1
		return
	if trigger_held:
		var along: float = (_context.missiles.get_missile_position(_steered_missile) - _context.aim_origin).dot(_context.aim_direction)
		_context.missiles.steer(_steered_missile, _context.aim_origin + _context.aim_direction * (maxf(along, 0.0) + STEER_LEAD_M))


## Missiles this salvo can fire: the salvo size, limited by the ammo left.
func _salvo_size() -> int:
	var size: int = _homing("salvo_size", 4)
	return size if ammo == UNLIMITED_AMMO else mini(size, ammo)


func _drop_dead_locks() -> void:
	for index: int in range(_locks.size() - 1, -1, -1):
		if not is_instance_valid(_locks[index]) or not _locks[index].is_alive():
			_locks.remove_at(index)


func _homing(key: String, fallback: Variant) -> Variant:
	var homing: Dictionary = data.get("homing", {})
	return homing.get(key, fallback)
