extends GutTest
## Integration tests for the M5 content: every weapon fires, every enemy
## spawns and runs, weak points and boss phases do what their data says.
## They run the real game scene with a non-persistent run.

const GAME_SCENE: String = "res://scenes/main/game.tscn"

var _game: Node3D
var _turret: Turret
var _enemies: EnemyManager
var _stages: StageManager
var _shots: int = 0


func before_all() -> void:
	EventBus.weapon_fired.connect(func(_slot: StringName) -> void: _shots += 1)


func before_each() -> void:
	GameState.persistent = false
	GameState._rebuild_tree()
	GameState.new_run()
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child_autofree(_game)
	_turret = _game.get_node("Turret")
	_enemies = _game.get_node("EnemyManager")
	_stages = _game.get_node("StageManager")
	_turret.player_input_enabled = false
	_turret.invulnerable = true
	_shots = 0
	await wait_frames(2)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false


## A point straight ahead of the turret at the given range and elevation.
func _ahead(distance_m: float, pitch_deg: float = 15.0) -> Vector3:
	return _turret.get_aim_transform().origin + TurretAim.direction_from(0.0, pitch_deg) * distance_m


func _aim_at(point: Vector3) -> void:
	var angles: Vector2 = _turret.get_aim_angles_to(point)
	_turret.aim.apply_input(angles.x - _turret.aim.yaw_deg, angles.y - _turret.aim.pitch_deg)


func _kill(target: CombatTarget) -> void:
	var info: DamageInfo = DamageInfo.new()
	info.amount = 1000000.0
	info.damage_type = "explosive"
	info.armour_pierce = 1000.0
	target.apply_damage(info)


func test_every_weapon_fires_from_its_slot() -> void:
	var dummy: Enemy = _enemies.spawn_enemy("bomber", _ahead(500.0))
	dummy.speed_mps = 0.0
	for weapon_id: String in GameData.loader.get_category("weapons"):
		var weapon_data: Dictionary = GameData.loader.get_entry("weapons", weapon_id)
		var slot: StringName = StringName((weapon_data["allowed_slots"] as Array)[0])
		assert_true(_turret.equip(slot, weapon_id), "%s can be equipped" % weapon_id)
		_turret.restore_for_stage()
		if not is_instance_valid(dummy) or dummy.stats.is_dead():
			dummy = _enemies.spawn_enemy("bomber", _ahead(500.0))
			dummy.speed_mps = 0.0
		dummy.stats.hp = dummy.stats.max_hp
		_aim_at(dummy.global_position)
		_shots = 0
		# Hold, then release (charge weapons and lock-on missiles fire on release).
		_turret.set_trigger(slot, true)
		await wait_seconds(1.6)
		_turret.set_trigger(slot, false)
		await wait_seconds(0.4)
		assert_gt(_shots, 0, "%s fired" % weapon_id)
	assert_eq(GameData.loader.get_category("weapons").size(), 20, "the full roster of section 4")


func test_every_enemy_spawns_and_runs() -> void:
	var ids: Array = GameData.loader.get_category("enemies").keys()
	assert_eq(ids.size(), 9, "the full roster of section 5")
	for enemy_id: String in ids:
		var enemy: Enemy = _enemies.spawn_enemy(enemy_id, _ahead(1500.0, 25.0))
		assert_not_null(enemy, enemy_id)
	await wait_seconds(1.5)
	assert_gte(_enemies.get_enemy_count(), 9, "nothing crashed or vanished")
	for enemy: Enemy in _enemies.get_enemies().duplicate():
		_kill(enemy)
	await wait_frames(3)
	assert_eq(_enemies.get_enemy_count(), 0, "every enemy can be destroyed")


func test_drone_reaches_the_turret_and_damages_it() -> void:
	_turret.invulnerable = false
	var hull_and_shield: float = _turret.hull + _turret.shield.charge
	_enemies.spawn_enemy("drone_swarmer", _ahead(60.0, 10.0))
	await wait_seconds(1.5)
	assert_lt(_turret.hull + _turret.shield.charge, hull_and_shield, "the ram hurt")
	assert_eq(_enemies.get_enemy_count(), 0, "the drone is gone")


func test_boss_shield_generators_switch_off_its_shield() -> void:
	var boss: Enemy = _enemies.spawn_enemy("boss_dreadnought", _ahead(2000.0))
	await wait_frames(2)
	assert_gt(boss.stats.shield, 0.0)
	assert_eq(boss.get_weak_points().size(), 9, "2 generators, 4 turrets, 3 engines")
	var generators: Array[WeakPoint] = []
	for weak_point: WeakPoint in boss.get_weak_points():
		if weak_point.data["group"] == "shield_generators":
			generators.append(weak_point)
	_kill(generators[0])
	await wait_frames(2)
	assert_gt(boss.stats.max_shield, 0.0, "one generator still holds the shield")
	_kill(generators[1])
	await wait_frames(2)
	assert_eq(boss.stats.max_shield, 0.0, "both gone: no shield")
	assert_eq(boss.stats.shield, 0.0)
	assert_true(boss.is_alive(), "the hull still has to be destroyed")


func test_boss_phases_enable_attacks_and_drones() -> void:
	var boss: Enemy = _enemies.spawn_enemy("boss_dreadnought", _ahead(2000.0))
	await wait_frames(2)
	assert_false(boss.spawn_enabled)
	assert_true(boss._disabled_attacks.has("missile_wall"))
	boss.stats.hp = boss.stats.max_hp * 0.6
	await wait_frames(2)
	assert_false(boss._disabled_attacks.has("missile_wall"), "phase 2 switches the missiles on")
	assert_false(boss.spawn_enabled)
	boss.stats.hp = boss.stats.max_hp * 0.3
	await wait_frames(2)
	assert_true(boss.spawn_enabled, "phase 3 launches drones")


func test_carrier_stops_launching_when_all_hangars_are_destroyed() -> void:
	var carrier: Enemy = _enemies.spawn_enemy("carrier", _ahead(1800.0))
	await wait_frames(2)
	var hp_before: float = carrier.stats.hp
	assert_true(carrier.spawn_enabled)
	for weak_point: WeakPoint in carrier.get_weak_points().duplicate():
		_kill(weak_point)
	await wait_frames(2)
	assert_false(carrier.spawn_enabled)
	assert_lt(carrier.stats.hp, hp_before, "each hangar also hurts the hull")


func test_shield_frigate_covers_allies_until_its_projector_dies() -> void:
	var frigate: Enemy = _enemies.spawn_enemy("shield_frigate", _ahead(1200.0))
	var ally: Enemy = _enemies.spawn_enemy("interceptor", _ahead(1200.0) + Vector3(60, 0, 0))
	ally.speed_mps = 0.0
	frigate.speed_mps = 0.0
	await wait_seconds(1.2)
	assert_gt(ally.stats.shield, 0.0, "the ally is covered")
	_kill(frigate.get_weak_points()[0])
	await wait_seconds(2.0)
	assert_eq(ally.stats.max_shield, 0.0, "cover ends after the projector is destroyed")
	assert_eq(frigate.stats.max_shield, 0.0, "and the frigate loses its own shield")


func test_shots_at_a_weak_point_damage_the_weak_point_not_the_hull() -> void:
	var boss: Enemy = _enemies.spawn_enemy("boss_dreadnought", _ahead(2000.0))
	boss.speed_mps = 0.0
	await wait_seconds(0.5)
	# The weak point nearest to the turret cannot be hidden behind another one.
	var nearest: WeakPoint = null
	for weak_point: WeakPoint in boss.get_weak_points():
		if nearest == null or weak_point.global_position.distance_to(_turret.global_position) < nearest.global_position.distance_to(_turret.global_position):
			nearest = weak_point
	var hp_before: float = nearest.stats.hp
	var hull_before: float = boss.stats.hp
	var shield_before: float = boss.stats.shield
	_aim_at(nearest.global_position)
	_turret.set_trigger(Turret.SLOT_PRIMARY, true)
	await wait_seconds(0.5)
	_turret.set_trigger(Turret.SLOT_PRIMARY, false)
	assert_lt(nearest.stats.hp, hp_before, "the weak point took the hits")
	assert_eq(boss.stats.hp, hull_before, "the hull did not")
	assert_gte(boss.stats.shield, shield_before, "nor did the ship's shield")


func test_weak_points_behind_the_hull_are_protected() -> void:
	var boss: Enemy = _enemies.spawn_enemy("boss_dreadnought", _ahead(2000.0))
	await wait_frames(2)
	var hull: Hurtbox = boss._hurtboxes[2]
	var far_side: WeakPoint = boss.get_weak_points()[0]
	# A shield generator sits on top of the ship: come at it from straight above.
	var from: Vector3 = far_side.global_position + Vector3(0, 500.0, 0)
	var direction: Vector3 = (far_side.global_position - from).normalized()
	assert_eq(hull.redirect(from, direction, 480.0).target, far_side, "reached before the hull: hit")
	assert_eq(hull.redirect(from, direction, 100.0).target, boss, "the hull was struck far in front of it: protected")

func test_emp_strips_shields_and_stuns_drones() -> void:
	var boat: Enemy = _enemies.spawn_enemy("missile_boat", _ahead(600.0))
	var drone: Enemy = _enemies.spawn_enemy("drone_swarmer", _ahead(600.0) + Vector3(20, 0, 0))
	boat.speed_mps = 0.0
	drone.speed_mps = 0.0
	await wait_frames(2)
	assert_gt(boat.stats.shield, 0.0)
	assert_true(_turret.equip(Turret.SLOT_ALTERNATE, "emp_burst"))
	_aim_at(boat.global_position)
	_turret.set_trigger(Turret.SLOT_ALTERNATE, true)
	await wait_seconds(0.2)
	_turret.set_trigger(Turret.SLOT_ALTERNATE, false)
	await wait_seconds(2.0)
	assert_eq(boat.stats.shield, 0.0, "the shield is stripped")
	assert_gt(drone._stagger_left_s, 0.0, "the drone is stunned")


func test_generated_boss_stages_scale_up() -> void:
	var director: Dictionary = GameData.loader.get_config("director")
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var normal: Dictionary = WaveDirector.procedural_stage(12, director, enemies, 10)
	assert_false(normal["boss"])
	assert_gt(float(normal["enemy_scale"]["hp"]), 1.0, "enemies get tougher beyond the authored stages")
	var boss_15: Dictionary = WaveDirector.procedural_stage(15, director, enemies, 10)
	var boss_20: Dictionary = WaveDirector.procedural_stage(20, director, enemies, 10)
	assert_true(boss_15["boss"])
	var group_15: Dictionary = (boss_15["waves"][0]["groups"] as Array)[0]
	var group_20: Dictionary = (boss_20["waves"][0]["groups"] as Array)[0]
	assert_eq(group_15["enemy"], "boss_dreadnought")
	assert_gt(float(group_20["scale"]["hp"]), float(group_15["scale"]["hp"]), "each boss is tougher than the last")
	var share: float = 0.0
	for wave: Dictionary in boss_15["waves"]:
		share += float(wave["budget_share"])
	assert_almost_eq(share, 0.5, 0.0001, "the escort gets half the budget")


func test_authored_stages_one_to_ten_exist_with_two_boss_stages() -> void:
	var bosses: Array[int] = []
	for number: int in range(1, 11):
		var stage: Dictionary = GameData.loader.get_entry("stages", "stage_%02d" % number)
		assert_false(stage.is_empty(), "stage %d" % number)
		if stage.get("boss", false):
			bosses.append(number)
	assert_eq(bosses, [5, 10] as Array[int])


func test_all_tree_nodes_are_in_the_build_now() -> void:
	for id: String in GameState.tree.get_node_ids():
		assert_true(GameState.is_node_in_build(id), id)
	assert_eq((GameData.loader.get_config("techtree")["planned_weapons"] as Array).size(), 0)
