class_name Enemy
extends CombatTarget
## One enemy craft. Its stats, behaviours, attacks, hit shapes and weak points
## all come from its data file (data/enemies/*.json); this class only runs them.
##
## Movement: behaviour modules set `velocity`, the enemy moves and faces the
## way it flies (or the turret, if a module asks for that). Attacks: a
## behaviour calls `try_attack()`; multi-shot attacks are played out over time
## here. Weak points are separate targets attached to the enemy.

## Enemy beams and bolts are drawn up to this distance from the turret.
const IMPACT_STANDOFF_M: float = 13.0
const ASSIST_INTERVAL_S: float = 0.12

var data: Dictionary = {}
var enemy_id: String = ""
var wave_index: int = 0
var speed_mps: float = 0.0
## True while the enemy is out of the fight between two passes.
var away: bool = false
## Multiplier on all damage this enemy deals (difficulty, boss scaling).
var damage_multiplier: float = 1.0
## Behaviour modules that launch other enemies check this (boss phases, hangars).
var spawn_enabled: bool = true
## Hovering craft keep their nose on the turret instead of their flight path.
var face_turret: bool = false
## Capital ships turn slowly on the spot, so every side (and every weak
## point) faces the turret sooner or later. Degrees per second; 0 = off.
var rotate_deg_s: float = 0.0
## Set by a behaviour that steers the ship's heading itself (`yaw_rad`).
var hold_heading: bool = false
## Heading around the up axis while `hold_heading` or `rotate_deg_s` is used.
var yaw_rad: float:
	get:
		return _rotation_rad
	set(value):
		_rotation_rad = value

var _manager: EnemyManager
var _turret: Turret
var _behaviours: Array[EnemyBehaviour] = []
var _behaviour_params: Array[Dictionary] = []
var _visual: Node3D
var _hurtboxes: Array[Hurtbox] = []
var _weak_points: Array[WeakPoint] = []
var _hardpoint: Node3D
var _cooldowns: PackedFloat32Array = []
var _disabled_attacks: Dictionary = {}  # attack id -> true
var _sequence_attack: Dictionary = {}
var _sequence_left: int = 0
var _sequence_timer_s: float = 0.0
var _stagger_left_s: float = 0.0
var _base_max_shield: float = 0.0
var _granted_shield_left_s: float = 0.0
var _granted_regen_per_s: float = 0.0
var _shield_bubble: MeshInstance3D
var _rotation_rad: float = 0.0
## Drawn by the manager's swarm renderer instead of having a model of its own,
## and advanced by the manager in one loop (data field "swarm").
var swarm: bool = false
## Changes every time the enemy is spawned or reused: lets others tell "the
## drone I launched" from "the same pooled object, now a different drone".
var life_id: int = 0
## Kept and reused by the manager after it is destroyed.
var pooled: bool = false
## Time of the last destruction (manager clock), so a pooled enemy rests a
## moment before it is reused.
var retired_at_s: float = 0.0
var _assist_left_s: float = 0.0
var _difficulty: Dictionary = {}
var _scale: Dictionary = {}


## Builds the enemy from its data. Called once, before it enters the tree.
## `scale` may hold `hp` and `damage` multipliers (boss scaling in endless mode).
func setup(enemy_data: Dictionary, manager: EnemyManager, turret: Turret, difficulty: Dictionary, scale: Dictionary = {}) -> void:
	data = enemy_data
	enemy_id = enemy_data["id"]
	name = enemy_id
	_manager = manager
	_turret = turret
	target_radius_m = enemy_data.get("hitbox_radius_m", 2.0)
	swarm = enemy_data.get("swarm", false)
	reset_state(difficulty, scale)
	var hp_scale: float = float(difficulty.get("enemy_hp_mult", 1.0)) * float(scale.get("hp", 1.0))

	if not swarm:
		var scene: PackedScene = GameData.assets.load_asset(enemy_data.get("model", "")) as PackedScene
		_visual = scene.instantiate() if scene != null else _fallback_visual()
		_visual.scale = Vector3.ONE * float(enemy_data.get("model_scale", 1.0))
		add_child(_visual)
		_hardpoint = _visual.find_child("Hardpoint_0", true, false) as Node3D

	# Hit shapes: one sphere by default, or the list in "hitboxes" for big ships.
	var hitboxes: Array = enemy_data.get("hitboxes", [])
	if hitboxes.is_empty():
		_add_hurtbox(Vector3.ZERO, target_radius_m)
	for hitbox: Dictionary in hitboxes:
		var offset: Array = hitbox.get("offset", [0.0, 0.0, 0.0])
		_add_hurtbox(Vector3(offset[0], offset[1], offset[2]), hitbox.get("radius_m", target_radius_m))

	for weak_point_data: Dictionary in enemy_data.get("weak_points", []):
		var weak_point: WeakPoint = WeakPoint.new()
		weak_point.setup(weak_point_data, self, hp_scale)
		add_child(weak_point)
		# A swarm enemy has no model of its own, so a weak point on one needs an "offset".
		var socket: Node3D = _visual.find_child(str(weak_point_data.get("socket", "")), true, false) as Node3D if _visual != null else null
		var offset: Array = weak_point_data.get("offset", [0.0, 0.0, 0.0])
		weak_point.position = socket.position * _visual.scale.x if socket != null else Vector3(offset[0], offset[1], offset[2])
		_weak_points.append(weak_point)

	for behaviour_id: String in enemy_data.get("behaviours", []):
		var behaviour_data: Dictionary = GameData.loader.get_entry("behaviours", behaviour_id)
		var behaviour: EnemyBehaviour = BehaviourRegistry.create(behaviour_data) if not behaviour_data.is_empty() else null
		if behaviour != null:
			_behaviours.append(behaviour)
			_behaviour_params.append(behaviour_data.get("params", {}))


## Everything that must be fresh each time the enemy enters the fight: health,
## cooldowns, flags. Called by `setup()` and again when a pooled enemy is reused.
func reset_state(difficulty: Dictionary, scale: Dictionary = {}) -> void:
	_difficulty = difficulty
	_scale = scale
	speed_mps = data["speed_mps"]
	damage_multiplier = float(difficulty.get("enemy_damage_mult", 1.0)) * float(scale.get("damage", 1.0))
	spawn_enabled = data.get("spawn_enabled", true)
	stats = TargetStats.from_data(data)
	var hp_scale: float = float(difficulty.get("enemy_hp_mult", 1.0)) * float(scale.get("hp", 1.0))
	stats.max_hp *= hp_scale
	stats.hp = stats.max_hp
	stats.max_shield *= float(scale.get("hp", 1.0))
	stats.shield = stats.max_shield
	_base_max_shield = stats.max_shield
	var attacks: Array = data.get("attacks", [])
	_cooldowns.resize(attacks.size())
	_cooldowns.fill(0.0)
	_disabled_attacks.clear()
	for attack: Dictionary in attacks:
		if not attack.get("enabled", true):
			_disabled_attacks[attack["id"]] = true
	_sequence_left = 0
	_stagger_left_s = 0.0
	_granted_shield_left_s = 0.0
	_rotation_rad = 0.0
	_assist_left_s = 0.0
	velocity = Vector3.ZERO
	away = false
	face_turret = false
	rotate_deg_s = 0.0
	hold_heading = false
	if _shield_bubble != null:
		_shield_bubble.visible = false


## Brings a pooled enemy back for a new spawn. The manager places it and
## calls `activate()` afterwards.
func revive(difficulty: Dictionary, scale: Dictionary = {}) -> void:
	reset_state(difficulty, scale)
	visible = true
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.reset_radius()
		hurtbox.set_enabled(true)
	set_process(not swarm)


## Starts the behaviours; called by the manager once the enemy is placed.
func activate() -> void:
	for index: int in _behaviours.size():
		_behaviours[index].setup(self, _behaviour_params[index])
	# Swarm members are advanced by the manager in one loop, not one by one.
	set_process(not swarm)


func _process(delta_s: float) -> void:
	advance(delta_s)


## One frame of the enemy: health, behaviours, attacks, movement.
func advance(delta_s: float) -> void:
	stats.tick(delta_s)
	if stats.is_dead():
		return
	_update_granted_shield(delta_s)
	for index: int in _cooldowns.size():
		_cooldowns[index] = maxf(0.0, _cooldowns[index] - delta_s)
	if _stagger_left_s > 0.0:
		# Staggered: drifts and cannot act until it recovers.
		_stagger_left_s -= delta_s
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-3.0 * delta_s))
		global_position += velocity * delta_s
		return
	for behaviour: EnemyBehaviour in _behaviours:
		behaviour.tick(delta_s)
		if not is_inside_tree() or is_queued_for_deletion() or stats.is_dead():
			return
	_update_attack_sequence(delta_s)
	# The hit shape only needs to follow the distance a few times per second.
	_assist_left_s -= delta_s
	if _assist_left_s <= 0.0:
		_assist_left_s = ASSIST_INTERVAL_S * randf_range(0.8, 1.2)
		var distance: float = global_position.distance_to(get_turret_point())
		for hurtbox: Hurtbox in _hurtboxes:
			hurtbox.apply_distance_assist(distance)
	global_position += velocity * delta_s
	if rotate_deg_s != 0.0 or hold_heading:
		_rotation_rad += deg_to_rad(rotate_deg_s) * delta_s
		global_transform = Transform3D(Basis(Vector3.UP, _rotation_rad), global_position)
		return
	var facing: Vector3 = (get_turret_point() - global_position) if face_turret else velocity
	if facing.length_squared() > 0.01:
		facing = facing.normalized()
		var up: Vector3 = Vector3.UP if absf(facing.y) < 0.99 else Vector3.RIGHT
		global_transform = Transform3D(Basis.looking_at(facing, up), global_position)


func is_alive() -> bool:
	return not away and super.is_alive()


func get_hit_radius() -> float:
	return _hurtboxes[0].radius_m if not _hurtboxes.is_empty() else target_radius_m


## True if the enemy's data lists this tag (e.g. "drone" for EMP stuns).
func has_tag(tag: String) -> bool:
	return (data.get("tags", []) as Array).has(tag)


## The enemy's weak points that are still intact.
func get_weak_points() -> Array[WeakPoint]:
	return _weak_points


func get_manager() -> EnemyManager:
	return _manager


## The point on the turret that enemies fly at and shoot at.
func get_turret_point() -> Vector3:
	return _turret.get_hit_point()


func get_turret_basis() -> Basis:
	return _turret.global_transform.basis


## Turns the velocity towards `point`, limited by the enemy's turn rate.
func steer_towards(point: Vector3, delta_s: float) -> void:
	var current: Vector3 = velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.FORWARD
	var desired: Vector3 = (point - global_position).normalized()
	var angle: float = current.angle_to(desired)
	if angle > 0.0005:
		var axis: Vector3 = current.cross(desired)
		if axis.length_squared() < 0.000001:
			axis = current.cross(Vector3.UP)
		var max_turn: float = deg_to_rad(data.get("turn_rate_deg_s", 90.0)) * delta_s
		current = current.rotated(axis.normalized(), minf(angle, max_turn)).normalized()
	velocity = current * speed_mps


## Starts the first enabled attack of the given type whose cooldown has run
## out. Returns true if an attack started.
func try_attack(attack_type: String) -> bool:
	return _try_attack_where(func(attack: Dictionary) -> bool: return attack["type"] == attack_type)


## Starts the attack with the given id if it is enabled and ready.
func try_attack_id(attack_id: String) -> bool:
	return _try_attack_where(func(attack: Dictionary) -> bool: return attack["id"] == attack_id)


## Switches an attack on or off (weak points and boss phases use this).
func set_attack_enabled(attack_id: String, enabled: bool) -> void:
	if enabled:
		_disabled_attacks.erase(attack_id)
	else:
		_disabled_attacks[attack_id] = true


## True while a multi-shot attack is still playing out.
func is_attacking() -> bool:
	return _sequence_left > 0


## Range of the first attack of a type, or 0 if the enemy has none.
func get_attack_range(attack_type: String) -> float:
	for attack: Dictionary in data.get("attacks", []):
		if attack["type"] == attack_type:
			return attack.get("range_m", 0.0)
	return 0.0


## Knocks the enemy out of control for a while (Phase Pulse, EMP).
func stagger(seconds: float) -> void:
	_stagger_left_s = maxf(_stagger_left_s, seconds)
	_sequence_left = 0


## A nearby shield projector covers this enemy: its shield is topped up to at
## least `amount` and regenerates while the cover lasts. Must be renewed.
func grant_shield(amount: float, regen_per_s: float, duration_s: float) -> void:
	if _granted_shield_left_s <= 0.0 and stats.shield < amount:
		stats.shield = amount
	_granted_shield_left_s = duration_s
	_granted_regen_per_s = regen_per_s
	stats.max_shield = maxf(_base_max_shield, amount)


## Removes the enemy's own shield for good (its generators were destroyed).
func disable_shield() -> void:
	_base_max_shield = 0.0
	stats.max_shield = 0.0
	stats.shield = 0.0
	stats.shield_regen_per_s = 0.0


## Flares: returns true if a missile aimed at this enemy loses its lock.
func try_flare() -> bool:
	var chance: float = (data.get("countermeasures", {}) as Dictionary).get("flare_chance", 0.0)
	if chance <= 0.0 or randf() >= chance:
		return false
	var fx: CombatFx = _manager.get_fx()
	if fx != null:
		for flare: int in 3:
			fx.flash(global_position + Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 4.0), randf_range(-12.0, 12.0)), 0.5, 3.0, Color(1.0, 0.9, 0.6), 0.6, 6.0)
	return true


## Takes the enemy out of the fight (hidden, cannot be hit) or brings it back.
func set_away(is_away: bool) -> void:
	away = is_away
	visible = not is_away
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.set_enabled(not is_away)


## Puts the enemy at a fresh spawn point in front and restarts its behaviours.
func return_for_new_pass() -> void:
	global_position = _manager.get_respawn_point(self)
	set_away(false)
	for behaviour: EnemyBehaviour in _behaviours:
		behaviour.reset()


## Destroys the enemy without credit to the player (it rammed the turret).
func self_destruct() -> void:
	_explode()
	stats.hp = 0.0
	_manager.notify_enemy_gone(self, false)


## Called by a weak point when it is destroyed: applies its own effect and,
## if it was the last of its group, the group's effect.
func on_weak_point_destroyed(weak_point: WeakPoint) -> void:
	_weak_points.erase(weak_point)
	_apply_weak_point_effect(weak_point.data.get("effect", {}))
	var group: String = weak_point.data.get("group", "")
	if group.is_empty():
		return
	for other: WeakPoint in _weak_points:
		if other.data.get("group", "") == group:
			return
	var groups: Dictionary = data.get("weak_point_groups", {})
	_apply_weak_point_effect((groups.get(group, {}) as Dictionary).get("when_all_destroyed", {}))


func _apply_weak_point_effect(effect: Dictionary) -> void:
	if effect.is_empty() or stats.is_dead():
		return
	if effect.get("disable_shield", false):
		disable_shield()
	if effect.get("disable_spawn", false):
		spawn_enabled = false
	for attack_id: Variant in effect.get("disable_attacks", []):
		set_attack_enabled(str(attack_id), false)
	if effect.has("speed_mult"):
		speed_mps *= float(effect["speed_mult"])
	if effect.has("message"):
		EventBus.ui_message.emit(effect["message"])
	var damage: float = effect.get("damage_to_owner", 0.0)
	if damage > 0.0:
		# Internal damage ignores shields and armour.
		stats.hp = maxf(1.0, stats.hp - damage)


func _on_killed() -> void:
	_explode()
	for weak_point: WeakPoint in _weak_points.duplicate():
		weak_point.queue_free()
	EventBus.enemy_killed.emit(StringName(enemy_id), int(data.get("credit_bounty", 0)))
	_manager.notify_enemy_gone(self, true)


## Out of the fight but kept for reuse: hidden, unhittable, not processed.
func retire(now_s: float) -> void:
	retired_at_s = now_s
	stats.hp = 0.0
	visible = false
	set_process(false)
	for hurtbox: Hurtbox in _hurtboxes:
		hurtbox.set_enabled(false)


func _try_attack_where(matches: Callable) -> bool:
	if _sequence_left > 0:
		return false
	var attacks: Array = data.get("attacks", [])
	for index: int in attacks.size():
		var attack: Dictionary = attacks[index]
		if _cooldowns[index] > 0.0 or _disabled_attacks.has(attack["id"]) or not matches.call(attack):
			continue
		_cooldowns[index] = attack.get("cooldown_s", 1.0)
		_sequence_attack = attack
		_sequence_left = attack.get("count", 1)
		_sequence_timer_s = 0.0
		_update_attack_sequence(0.0)
		return true
	return false


func _update_attack_sequence(delta_s: float) -> void:
	if _sequence_left <= 0:
		return
	_sequence_timer_s -= delta_s
	while _sequence_left > 0 and _sequence_timer_s <= 0.0:
		_perform(_sequence_attack)
		_sequence_left -= 1
		_sequence_timer_s += maxf(float(_sequence_attack.get("interval_s", 0.1)), 0.001)


## Executes one shot, bomb or ram of an attack.
func _perform(attack: Dictionary) -> void:
	var damage: float = float(attack["damage"]) * damage_multiplier
	var origin: Vector3 = _hardpoint.global_position if _hardpoint != null else global_position
	match attack["type"]:
		"collision":
			_turret.take_damage(damage, global_position, attack.get("damage_type", "kinetic"))
		"hitscan_burst":
			_turret.take_damage(damage, origin, attack.get("damage_type", "energy"))
			var fx: CombatFx = _manager.get_fx()
			if fx != null:
				var color_values: Array = attack.get("color", [1.0, 0.3, 0.2])
				var color: Color = Color(color_values[0], color_values[1], color_values[2])
				# The shot ends a little short of the turret (where a shield would stop it):
				# a thick beam drawn right up to the camera would fill the whole view.
				var target_point: Vector3 = get_turret_point() + Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.5), randf_range(-2.0, 2.0))
				var impact: Vector3 = target_point + (origin - target_point).normalized() * IMPACT_STANDOFF_M
				var width: float = attack.get("width_m", 0.25)
				fx.tracer(origin, impact, color, width, 0.09, 5.0)
				# A small spark only: the shield ripple and the damage frame show the hit.
				fx.flash(impact, 0.1, 0.35 + width * 0.3, color, 0.08, 4.0)
		"guided_bomb":
			var spread: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-1.0, 1.0)) * float(attack.get("launch_spread_mps", 0.0))
			_manager.spawn_projectile(attack, origin + Vector3.DOWN * 2.0, velocity + spread, damage)


func _update_granted_shield(delta_s: float) -> void:
	if _granted_shield_left_s > 0.0:
		_granted_shield_left_s -= delta_s
		stats.shield = minf(stats.max_shield, stats.shield + _granted_regen_per_s * delta_s)
		if _granted_shield_left_s <= 0.0:
			stats.max_shield = _base_max_shield
			stats.shield = minf(stats.shield, _base_max_shield)
	var covered: bool = _granted_shield_left_s > 0.0 and stats.shield > 0.0
	if covered and _shield_bubble == null:
		_shield_bubble = _manager.make_shield_bubble(target_radius_m * 1.4)
		add_child(_shield_bubble)
	if _shield_bubble != null:
		_shield_bubble.visible = covered


func _add_hurtbox(offset: Vector3, radius_m: float) -> void:
	var hurtbox: Hurtbox = Hurtbox.create_sphere(self, radius_m)
	hurtbox.position = offset
	add_child(hurtbox)
	_hurtboxes.append(hurtbox)


func _explode() -> void:
	var fx: CombatFx = _manager.get_fx()
	if fx == null:
		return
	var effect: Dictionary = data.get("death_effect", {})
	var color_values: Array = effect.get("color", [1.0, 0.5, 0.2])
	fx.explosion(global_position, effect.get("radius_m", 8.0), Color(color_values[0], color_values[1], color_values[2]))


func _fallback_visual() -> Node3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 1.0, 3.0)
	instance.mesh = mesh
	return instance
