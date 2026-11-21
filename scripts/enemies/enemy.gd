class_name Enemy
extends CombatTarget
## One enemy craft. Its stats, behaviours and attacks all come from its data
## file (data/enemies/*.json); this class only runs them.
##
## Movement: behaviour modules set `velocity`, the enemy moves and faces the
## way it flies. Attacks: a behaviour calls `try_attack(type)`; multi-shot
## attacks are then played out over time here.

var data: Dictionary = {}
var enemy_id: String = ""
var wave_index: int = 0
var speed_mps: float = 0.0
## True while the enemy is out of the fight between two passes.
var away: bool = false
## Multiplier on all damage this enemy deals (difficulty).
var damage_multiplier: float = 1.0

var _manager: EnemyManager
var _turret: Turret
var _behaviours: Array[EnemyBehaviour] = []
var _behaviour_params: Array[Dictionary] = []
var _visual: Node3D
var _hurtbox: Hurtbox
var _hardpoint: Node3D
var _cooldowns: PackedFloat32Array = []
var _sequence_attack: Dictionary = {}
var _sequence_left: int = 0
var _sequence_timer_s: float = 0.0


## Builds the enemy from its data. Called once, before it enters the tree.
func setup(enemy_data: Dictionary, manager: EnemyManager, turret: Turret, difficulty: Dictionary) -> void:
	data = enemy_data
	enemy_id = enemy_data["id"]
	name = enemy_id
	_manager = manager
	_turret = turret
	speed_mps = enemy_data["speed_mps"]
	target_radius_m = enemy_data.get("hitbox_radius_m", 2.0)
	damage_multiplier = difficulty.get("enemy_damage_mult", 1.0)
	stats = TargetStats.from_data(enemy_data)
	stats.max_hp *= float(difficulty.get("enemy_hp_mult", 1.0))
	stats.hp = stats.max_hp

	var scene: PackedScene = GameData.assets.load_asset(enemy_data.get("model", "")) as PackedScene
	_visual = scene.instantiate() if scene != null else _fallback_visual()
	_visual.scale = Vector3.ONE * float(enemy_data.get("model_scale", 1.0))
	add_child(_visual)
	_hardpoint = _visual.find_child("Hardpoint_0", true, false) as Node3D
	_hurtbox = Hurtbox.create_sphere(self, target_radius_m)
	add_child(_hurtbox)

	_cooldowns.resize((enemy_data.get("attacks", []) as Array).size())
	for behaviour_id: String in enemy_data.get("behaviours", []):
		var behaviour_data: Dictionary = GameData.loader.get_entry("behaviours", behaviour_id)
		var behaviour: EnemyBehaviour = BehaviourRegistry.create(behaviour_data) if not behaviour_data.is_empty() else null
		if behaviour != null:
			_behaviours.append(behaviour)
			_behaviour_params.append(behaviour_data.get("params", {}))


## Starts the behaviours; called by the manager once the enemy is placed.
func activate() -> void:
	for index: int in _behaviours.size():
		_behaviours[index].setup(self, _behaviour_params[index])


func _process(delta_s: float) -> void:
	super._process(delta_s)
	if stats.is_dead():
		return
	for index: int in _cooldowns.size():
		_cooldowns[index] = maxf(0.0, _cooldowns[index] - delta_s)
	for behaviour: EnemyBehaviour in _behaviours:
		behaviour.tick(delta_s)
		if not is_inside_tree() or is_queued_for_deletion():
			return
	_update_attack_sequence(delta_s)
	if velocity.length_squared() > 0.01:
		global_position += velocity * delta_s
		var direction: Vector3 = velocity.normalized()
		var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
		global_transform = Transform3D(Basis.looking_at(direction, up), global_position)


func is_alive() -> bool:
	return not away and super.is_alive()


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


## Starts the first attack of the given type whose cooldown has run out.
## Returns true if an attack started.
func try_attack(attack_type: String) -> bool:
	if _sequence_left > 0:
		return false
	var attacks: Array = data.get("attacks", [])
	for index: int in attacks.size():
		var attack: Dictionary = attacks[index]
		if attack["type"] != attack_type or _cooldowns[index] > 0.0:
			continue
		_cooldowns[index] = attack.get("cooldown_s", 1.0)
		_sequence_attack = attack
		_sequence_left = attack.get("count", 1)
		_sequence_timer_s = 0.0
		_update_attack_sequence(0.0)
		return true
	return false


## True while a multi-shot attack is still playing out.
func is_attacking() -> bool:
	return _sequence_left > 0


## Range of the first attack of a type, or 0 if the enemy has none.
func get_attack_range(attack_type: String) -> float:
	for attack: Dictionary in data.get("attacks", []):
		if attack["type"] == attack_type:
			return attack.get("range_m", 0.0)
	return 0.0


## Takes the enemy out of the fight (hidden, cannot be hit) or brings it back.
func set_away(is_away: bool) -> void:
	away = is_away
	visible = not is_away
	_hurtbox.set_enabled(not is_away)


## Puts the enemy at a fresh spawn point in front and restarts its behaviours.
func return_for_new_pass() -> void:
	global_position = _manager.get_respawn_point(self)
	set_away(false)
	for behaviour: EnemyBehaviour in _behaviours:
		behaviour.reset()


## Destroys the enemy without credit to the player (it rammed the turret).
func self_destruct() -> void:
	_explode()
	_manager.notify_enemy_gone(self, false)
	queue_free()


func _on_killed() -> void:
	_explode()
	EventBus.enemy_killed.emit(StringName(enemy_id), int(data.get("credit_bounty", 0)))
	_manager.notify_enemy_gone(self, true)
	queue_free()


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
			_turret.take_damage(damage)
		"hitscan_burst":
			_turret.take_damage(damage)
			var fx: CombatFx = _manager.get_fx()
			if fx != null:
				var color_values: Array = attack.get("color", [1.0, 0.3, 0.2])
				var color: Color = Color(color_values[0], color_values[1], color_values[2])
				var impact: Vector3 = get_turret_point() + Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.5), randf_range(-2.0, 2.0))
				fx.tracer(origin, impact, color, 0.25, 0.09, 5.0)
				fx.flash(impact, 0.4, 1.6, color, 0.12, 5.0)
		"guided_bomb":
			_manager.spawn_projectile(attack, origin + Vector3.DOWN * 2.0, velocity, damage)


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
