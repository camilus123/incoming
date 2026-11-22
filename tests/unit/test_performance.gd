extends GutTest
## Performance pass (M7): the swarm renderer, pooling, the target registry and
## the benchmark data. They run the real game scene with a non-persistent run.

const GAME_SCENE: String = "res://scenes/main/game.tscn"

var _game: Node3D
var _turret: Turret
var _enemies: EnemyManager


func before_each() -> void:
	GameState.persistent = false
	GameState._rebuild_tree()
	GameState.new_run()
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child_autofree(_game)
	_turret = _game.get_node("Turret")
	_enemies = _game.get_node("EnemyManager")
	_turret.player_input_enabled = false
	_turret.invulnerable = true
	await wait_frames(2)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false


func _ahead(distance_m: float, yaw_deg: float = 0.0) -> Vector3:
	return _turret.get_aim_transform().origin + TurretAim.direction_from(yaw_deg, 20.0) * distance_m


func _kill(target: CombatTarget) -> void:
	var info: DamageInfo = DamageInfo.new()
	info.amount = 1000000.0
	info.armour_pierce = 1000000.0
	target.apply_damage(info)


func test_swarm_drones_have_no_model_and_are_drawn_as_one_multimesh() -> void:
	for index: int in 30:
		_enemies.spawn_enemy("drone_swarmer", _ahead(1500.0, -30.0 + index * 2.0))
	await wait_frames(3)
	assert_eq(_enemies.get_swarm_count(), 30)
	var renderers: Array[Node] = _enemies.find_children("*", "MultiMeshInstance3D", true, false)
	assert_eq(renderers.size(), 1, "one MultiMesh for the whole swarm")
	assert_eq((renderers[0].get_parent() as SwarmRenderer).get_count(), 30, "every live drone was handed to the renderer this frame")
	var drone: Enemy = _enemies.get_enemies()[0]
	assert_eq(drone.find_children("*", "MeshInstance3D", true, false).size(), 0, "a swarm drone carries no meshes of its own")
	assert_false(drone.is_processing(), "the manager advances swarm members")


func test_swarm_drones_still_fly_at_the_turret() -> void:
	var drone: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(1200.0))
	var start: float = drone.global_position.distance_to(_turret.global_position)
	await wait_seconds(1.0)
	assert_lt(drone.global_position.distance_to(_turret.global_position), start - 40.0, "70 m/s towards the turret")


func test_the_merged_swarm_mesh_keeps_every_part_of_the_model() -> void:
	var data: Dictionary = GameData.loader.get_entry("enemies", "drone_swarmer")
	var model: Node3D = (GameData.assets.load_asset(data["model"]) as PackedScene).instantiate()
	var triangles: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	var merged: ArrayMesh = SwarmRenderer.merge_meshes(model)
	model.free()
	assert_not_null(merged)
	var merged_triangles: int = 0
	for surface: int in merged.get_surface_count():
		var arrays: Array = merged.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		merged_triangles += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	assert_gt(triangles, 0)
	assert_eq(merged_triangles, triangles)


func test_a_destroyed_drone_is_pooled_and_reused_after_a_rest() -> void:
	var first: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(1500.0))
	var first_life: int = first.life_id
	_kill(first)
	assert_false(first.is_alive())
	assert_eq(_enemies.get_enemy_count(), 0)
	assert_eq(_enemies.get_pooled_count(), 1, "kept, not freed")
	var second: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(1500.0))
	assert_ne(second, first, "not reused straight away: something may still point at the dead one")
	await wait_seconds(EnemyManager.POOL_REST_S + 0.3)
	var third: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(1400.0))
	assert_eq(third, first, "reused after the rest")
	assert_true(third.is_alive())
	assert_eq(third.stats.hp, third.stats.max_hp, "back to full health")
	assert_ne(third.life_id, first_life, "but it counts as a new enemy")
	assert_eq(_enemies.get_enemy_count(), 2)


func test_big_ships_are_not_pooled() -> void:
	var gunship: Enemy = _enemies.spawn_enemy("gunship", _ahead(1500.0))
	_kill(gunship)
	await wait_frames(2)
	assert_eq(_enemies.get_pooled_count(), 0)
	assert_false(is_instance_valid(gunship), "freed as before")


func test_enemy_projectiles_are_pooled() -> void:
	var boat_data: Dictionary = GameData.loader.get_entry("enemies", "bomber")
	var attack: Dictionary = {}
	for candidate: Dictionary in boat_data["attacks"]:
		if candidate["type"] == "guided_bomb":
			attack = candidate
	assert_false(attack.is_empty(), "the bomber drops bombs")
	var bomb: EnemyProjectile = _enemies.spawn_projectile(attack, _ahead(900.0), Vector3.ZERO, 10.0)
	_kill(bomb)
	assert_eq(_enemies.get_projectile_count(), 0)
	assert_eq(_enemies.get_pooled_count(), 1)
	await wait_seconds(EnemyManager.POOL_REST_S + 0.3)
	var again: EnemyProjectile = _enemies.spawn_projectile(attack, _ahead(900.0), Vector3.ZERO, 10.0)
	assert_eq(again, bomb)
	assert_true(again.is_alive())


func test_a_missile_lets_go_of_a_destroyed_target() -> void:
	var missiles: MissileSystem = _game.get_node("MissileSystem")
	var drone: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(1500.0))
	var weapon: Dictionary = GameData.loader.get_entry("weapons", "micro_missile_pod")
	var handle: int = missiles.launch(_turret.get_aim_transform().origin + Vector3.UP * 5.0, Vector3.UP, drone, weapon, Turret.SLOT_ALTERNATE)
	await wait_frames(2)
	_kill(drone)
	await wait_frames(3)
	assert_null(missiles._missiles[handle].target, "it must not chase the drone when the pool brings it back")


func test_the_target_registry_follows_the_scene_tree() -> void:
	var before: int = CombatTarget.registry.size()
	var gunship: Enemy = _enemies.spawn_enemy("gunship", _ahead(1500.0))
	assert_true(CombatTarget.registry.has(gunship))
	assert_eq(CombatTarget.registry.size(), before + 1)
	_kill(gunship)
	await wait_frames(2)
	assert_eq(CombatTarget.registry.size(), before, "freed targets leave the registry")


func test_clearing_the_field_leaves_nothing_in_play() -> void:
	for index: int in 12:
		_enemies.spawn_enemy("drone_swarmer", _ahead(1500.0, index * 3.0))
	_enemies.spawn_enemy("gunship", _ahead(1500.0))
	_enemies.clear_all()
	await wait_frames(3)
	assert_eq(_enemies.get_enemy_count(), 0)
	assert_eq(_enemies.get_swarm_count(), 0)
	for target: CombatTarget in CombatTarget.registry:
		assert_false(target is Enemy and target.is_alive(), "no live enemy remains")


func test_the_benchmark_stage_is_valid_and_heavy() -> void:
	var stage: Dictionary = GameData.loader.get_config("benchmark_stage")
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var total: int = 0
	for wave: Dictionary in stage["waves"]:
		for group: Dictionary in wave["groups"]:
			assert_true(enemies.has(group["enemy"]), "benchmark enemy '%s' exists" % group["enemy"])
			total += int(group["count"])
	assert_gt(total, 250, "far more than a real stage")
	assert_gt(float(GameData.loader.get_config("benchmark")["duration_s"]), 30.0)
