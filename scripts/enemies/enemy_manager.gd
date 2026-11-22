class_name EnemyManager
extends Node3D
## Owns every enemy and enemy projectile in play: spawning, counting and
## clean-up. All spawning goes through here so pooling and the MultiMesh
## swarm renderer (M7) can be added without touching the callers.

const GROUP: StringName = &"enemy_manager"

## The active difficulty level's multipliers (difficulty.json).
var difficulty: Dictionary = {}

var _enemies: Array[Enemy] = []
var _projectiles: Array[EnemyProjectile] = []
var _turret: Turret
var _fx: CombatFx
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Glow materials shared by all markers of one look: "tint|intensity" -> material.
var _glow_materials: Dictionary = {}


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
	var enemy: Enemy = Enemy.new()
	enemy.setup(enemy_data, self, _get_turret(), difficulty, scale)
	enemy.wave_index = wave_index
	add_child(enemy)
	enemy.global_position = at
	enemy.activate()
	_enemies.append(enemy)
	return enemy


## Spawns a shootable projectile for an enemy attack.
func spawn_projectile(attack: Dictionary, at: Vector3, start_velocity: Vector3, damage: float) -> EnemyProjectile:
	var projectile: EnemyProjectile = EnemyProjectile.new()
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
	for enemy: Enemy in _enemies:
		enemy.queue_free()
	for projectile: EnemyProjectile in _projectiles:
		projectile.queue_free()
	_enemies.clear()
	_projectiles.clear()


## Called by an enemy when it is destroyed or destroys itself.
func notify_enemy_gone(enemy: Enemy, _killed_by_player: bool) -> void:
	_enemies.erase(enemy)


func notify_projectile_gone(projectile: EnemyProjectile) -> void:
	_projectiles.erase(projectile)


func _get_turret() -> Turret:
	if _turret == null:
		_turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	return _turret
