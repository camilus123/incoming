class_name EnemyManager
extends Node3D
## Owns every enemy and enemy projectile in play: spawning, counting and
## clean-up. All spawning goes through here.
##
## Performance work lives here too:
## - Swarm enemies (data field "swarm") have no model of their own. They are
##   drawn by a [SwarmRenderer] (one MultiMesh per model) and advanced in one
##   loop in `_process` instead of each running its own.
## - Swarm enemies and enemy projectiles are pooled: a destroyed one is hidden
##   and reused for a later spawn after a short rest.
## - `prewarm()` builds each enemy type of a stage once during the intro, so
##   its first appearance does not cost a long frame.

const GROUP: StringName = &"enemy_manager"
## A destroyed pooled object rests this long before reuse, so anything that
## still points at it (a missile, a lock) sees it dead first and lets go.
const POOL_REST_S: float = 1.5

## The active difficulty level's multipliers (difficulty.json).
var difficulty: Dictionary = {}

var _enemies: Array[Enemy] = []
var _projectiles: Array[EnemyProjectile] = []
var _turret: Turret
var _fx: CombatFx
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Glow materials shared by all markers of one look: "tint|intensity" -> material.
var _glow_materials: Dictionary = {}
var _clock_s: float = 0.0
var _next_life_id: int = 1
## Swarm members in play, advanced here.
var _swarm: Array[Enemy] = []
var _swarm_renderers: Dictionary = {}  # model asset id -> SwarmRenderer
var _enemy_pool: Dictionary = {}  # enemy id -> Array[Enemy]
var _projectile_pool: Dictionary = {}  # pool key -> Array[EnemyProjectile]
var _prewarmed: Dictionary = {}  # enemy id -> true


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_rng.randomize()
	_fx = get_tree().get_first_node_in_group(CombatFx.GROUP) as CombatFx


## Spawns one enemy of the given type. Returns null if the type is unknown.
## `scale` may hold `hp` and `damage` multipliers (boss scaling).
func spawn_enemy(enemy_id: String, at: Vector3, wave_index: int = 0, scale: Dictionary = {}) -> Enemy:
	var enemy_data: Dictionary = GameData.loader.get_entry("enemies", enemy_id)
	if enemy_data.is_empty():
		push_warning("EnemyManager: unknown enemy \"%s\"" % enemy_id)
		return null
	var enemy: Enemy = _take_pooled_enemy(enemy_id)
	if enemy != null:
		enemy.revive(difficulty, scale)
	else:
		enemy = Enemy.new()
		enemy.setup(enemy_data, self, _get_turret(), difficulty, scale)
		enemy.pooled = enemy.swarm
		add_child(enemy)
	enemy.life_id = _next_life_id
	_next_life_id += 1
	enemy.wave_index = wave_index
	enemy.global_position = at
	enemy.activate()
	_enemies.append(enemy)
	if enemy.swarm:
		_swarm.append(enemy)
		_ensure_swarm_renderer(enemy_data)
	return enemy


## Spawns a shootable projectile for an enemy attack.
func spawn_projectile(attack: Dictionary, at: Vector3, start_velocity: Vector3, damage: float) -> EnemyProjectile:
	var projectile: EnemyProjectile = _take_pooled_projectile(EnemyProjectile.key_for(attack))
	if projectile != null:
		projectile.restart(attack, start_velocity, damage)
	else:
		projectile = EnemyProjectile.new()
		projectile.setup(attack, start_velocity, damage, self, _get_turret())
		add_child(projectile)
	projectile.global_position = at
	_projectiles.append(projectile)
	return projectile


## Enemies still in the stage, including ones circling round for a new pass.
func get_enemy_count() -> int:
	return _enemies.size()


## Enemies of one wave still in the stage.
func get_wave_count(wave_index: int) -> int:
	var count: int = 0
	for enemy: Enemy in _enemies:
		if enemy.wave_index == wave_index:
			count += 1
	return count


func get_projectile_count() -> int:
	return _projectiles.size()


## All enemies in play (read only; used by the HUD).
func get_enemies() -> Array[Enemy]:
	return _enemies


func get_projectiles() -> Array[EnemyProjectile]:
	return _projectiles


func get_fx() -> CombatFx:
	return _fx


## A faint bubble shown around an enemy that is covered by a shield projector.
func make_shield_bubble(radius_m: float) -> MeshInstance3D:
	return _make_glow_sphere(radius_m, Color(0.4, 0.8, 1.0, 0.12), 2.0)


## A bright core that marks a weak point.
func make_weak_point_marker(radius_m: float) -> MeshInstance3D:
	return _make_glow_sphere(radius_m, Color(1.0, 0.85, 0.3, 0.8), 3.0)


func _make_glow_sphere(radius_m: float, tint: Color, intensity: float) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius_m
	sphere.height = radius_m * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var key: String = "%s|%s" % [tint, intensity]
	if not _glow_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GameData.assets.load_asset("vfx.shader.glow_static") as Shader
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"intensity", intensity)
		_glow_materials[key] = material
	sphere.material = _glow_materials[key]
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = sphere
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## A new spawn point in front of the turret for an enemy starting another pass.
func get_respawn_point(enemy: Enemy) -> Vector3:
	var director: Dictionary = GameData.loader.get_config("director")
	var region: Dictionary = WaveDirector.spawn_region({}, {}, enemy.data, director)
	var point: Vector3 = WaveDirector.random_point(region, _rng)
	var turret: Turret = _get_turret()
	var spawn_point: Vector3 = turret.get_aim_transform().origin + turret.global_transform.basis * TurretAim.direction_from(point.x, point.y) * point.z
	spawn_point.y = maxf(spawn_point.y, director.get("min_spawn_altitude_m", 40.0))
	return spawn_point


## Removes everything without effects or credit (stage restart).
func clear_all() -> void:
	for enemy: Enemy in _enemies.duplicate():
		_remove_enemy(enemy)
	for projectile: EnemyProjectile in _projectiles.duplicate():
		notify_projectile_gone(projectile)
	_enemies.clear()
	_projectiles.clear()
	_swarm.clear()


## Called by an enemy when it is destroyed or destroys itself.
func notify_enemy_gone(enemy: Enemy, _killed_by_player: bool) -> void:
	_remove_enemy(enemy)


func notify_projectile_gone(projectile: EnemyProjectile) -> void:
	_projectiles.erase(projectile)
	projectile.retire(_clock_s)
	if not _projectile_pool.has(projectile.pool_key):
		_projectile_pool[projectile.pool_key] = []
	(_projectile_pool[projectile.pool_key] as Array).append(projectile)


## Builds each enemy type of a stage once, out of sight, so the cost of its
## first appearance (loading and instancing its model) is paid during the
## stage intro instead of in the middle of a fight.
func prewarm(stage_data: Dictionary) -> void:
	var ids: Dictionary = {}
	for wave: Dictionary in stage_data.get("waves", []):
		for group: Dictionary in wave.get("groups", []):
			ids[str(group.get("enemy", ""))] = true
		for enemy_id: Variant in wave.get("enemies", []):
			ids[str(enemy_id)] = true
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var pending: Array[String] = []
	for enemy_id: String in ids:
		pending.append(enemy_id)
	# Enemies launched by other enemies (carrier drones) count too.
	while not pending.is_empty():
		var enemy_id: String = pending.pop_back()
		if _prewarmed.has(enemy_id) or not enemies.has(enemy_id):
			continue
		_prewarmed[enemy_id] = true
		var enemy_data: Dictionary = enemies[enemy_id]
		for behaviour_id: Variant in enemy_data.get("behaviours", []):
			var child_id: String = str((GameData.loader.get_entry("behaviours", str(behaviour_id)).get("params", {}) as Dictionary).get("enemy", ""))
			if not child_id.is_empty():
				pending.append(child_id)
		if enemy_data.get("swarm", false):
			_ensure_swarm_renderer(enemy_data)
			continue
		# Instancing the model once loads its meshes and materials into memory.
		var scene: PackedScene = GameData.assets.load_asset(enemy_data.get("model", "")) as PackedScene
		if scene != null:
			var model: Node = scene.instantiate()
			model.free()


## Enemies and projectiles waiting in the pools (for the debug overlay and tests).
func get_pooled_count() -> int:
	var count: int = 0
	for pool: Array in _enemy_pool.values():
		count += pool.size()
	for pool: Array in _projectile_pool.values():
		count += pool.size()
	return count


func get_swarm_count() -> int:
	return _swarm.size()


func _process(delta_s: float) -> void:
	_clock_s += delta_s
	for renderer: SwarmRenderer in _swarm_renderers.values():
		renderer.begin()
	# Backwards, because a member that rams the turret removes itself.
	for index: int in range(_swarm.size() - 1, -1, -1):
		var member: Enemy = _swarm[index]
		member.advance(delta_s)
		if member.stats.is_dead() or member.away:
			continue
		var renderer: SwarmRenderer = _swarm_renderers.get(member.data.get("model", ""))
		if renderer != null:
			renderer.add(member.global_transform)
	for renderer: SwarmRenderer in _swarm_renderers.values():
		renderer.finish()


func _remove_enemy(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if enemy.swarm:
		_swarm.erase(enemy)
	if not enemy.pooled:
		enemy.queue_free()
		return
	enemy.retire(_clock_s)
	if not _enemy_pool.has(enemy.enemy_id):
		_enemy_pool[enemy.enemy_id] = []
	(_enemy_pool[enemy.enemy_id] as Array).append(enemy)


func _take_pooled_enemy(enemy_id: String) -> Enemy:
	var pool: Array = _enemy_pool.get(enemy_id, [])
	# The pool is in order of retirement, so only the oldest needs checking.
	if pool.is_empty() or _clock_s - (pool[0] as Enemy).retired_at_s < POOL_REST_S:
		return null
	return pool.pop_front() as Enemy


func _take_pooled_projectile(key: String) -> EnemyProjectile:
	var pool: Array = _projectile_pool.get(key, [])
	if pool.is_empty() or _clock_s - (pool[0] as EnemyProjectile).retired_at_s < POOL_REST_S:
		return null
	return pool.pop_front() as EnemyProjectile


func _ensure_swarm_renderer(enemy_data: Dictionary) -> void:
	var model_id: String = enemy_data.get("model", "")
	if _swarm_renderers.has(model_id):
		return
	var renderer: SwarmRenderer = SwarmRenderer.create(model_id, enemy_data.get("model_scale", 1.0))
	_swarm_renderers[model_id] = renderer
	if renderer != null:
		add_child(renderer)


func _get_turret() -> Turret:
	if _turret == null:
		_turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	return _turret
