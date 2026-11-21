extends Weapon
## Archetype "homing": guided missiles fired in salvos (Micro-Missile Pod).
##
## Hold the trigger with the crosshair near targets to collect locks, one
## every `lock_time_s`. Release to launch the salvo; missiles are shared out
## between the locked targets, or fly straight if nothing is locked. Then the
## pod reloads. Missiles use a per-stage ammo stock, not reactor power.

var _locks: Array[CombatTarget] = []
var _lock_timer_s: float = 0.0
var _reload_left_s: float = 0.0
var _was_held: bool = false
## Targets of missiles waiting to leave the pod (null = unguided).
var _launch_queue: Array[CombatTarget] = []
var _launch_timer_s: float = 0.0


func get_reload_fraction() -> float:
	var reload_s: float = _homing("reload_s", 6.0)
	return clampf(_reload_left_s / reload_s, 0.0, 1.0) if reload_s > 0.0 else 0.0


func get_lock_targets() -> Array[CombatTarget]:
	return _locks


func get_lock_progress() -> float:
	var lock_time_s: float = _homing("lock_time_s", 0.3)
	if not trigger_held or lock_time_s <= 0.0 or _locks.size() >= _salvo_size():
		return 0.0
	return clampf(_lock_timer_s / lock_time_s, 0.0, 1.0)


func _update_weapon(delta_s: float) -> void:
	_reload_left_s = maxf(0.0, _reload_left_s - delta_s)
	_drop_dead_locks()
	var ready: bool = _reload_left_s <= 0.0 and _launch_queue.is_empty() and heat.can_fire() and has_ammo()

	if trigger_held and ready:
		_update_locking(delta_s)
	elif _was_held and not trigger_held and ready:
		_start_salvo()
	if not trigger_held:
		_locks.clear()
		_lock_timer_s = 0.0
	_was_held = trigger_held

	_update_launching(delta_s)


func _update_locking(delta_s: float) -> void:
	if _locks.size() >= _salvo_size():
		return
	_lock_timer_s += delta_s
	if _lock_timer_s < _homing("lock_time_s", 0.3):
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


func _start_salvo() -> void:
	var count: int = _salvo_size()
	for index: int in count:
		_launch_queue.append(_locks[index % _locks.size()] if not _locks.is_empty() else null)
	_launch_timer_s = 0.0
	_reload_left_s = _homing("reload_s", 6.0)
	_locks.clear()
	_lock_timer_s = 0.0


func _update_launching(delta_s: float) -> void:
	if _launch_queue.is_empty():
		return
	_launch_timer_s -= delta_s
	while _launch_timer_s <= 0.0 and not _launch_queue.is_empty():
		var queued: Variant = _launch_queue.pop_front()
		# The target may have been destroyed and freed while the missile waited.
		_launch(queued as CombatTarget if is_instance_valid(queued) else null)
		_launch_timer_s += maxf(_homing("launch_interval_s", 0.1), 0.001)


func _launch(target: CombatTarget) -> void:
	if ammo != UNLIMITED_AMMO:
		ammo -= 1
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.missiles != null:
		_context.missiles.launch(muzzle, _context.aim_direction, target, data, slot)
	if _context.fx != null:
		_context.fx.flash(muzzle, 0.1, 0.5, _tracer_color, 0.09, 5.0)
	_apply_shot_feedback()


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
