extends GutTest
## Tests for WaveDirector, StageStats and the shipped stage and enemy data.

const DIRECTOR: Dictionary = {
	"base_budget": 100.0,
	"growth": 1.18,
	"default_spawn": {"yaw_deg": [-60.0, 60.0], "pitch_deg": [8.0, 40.0], "distance_m": [1200.0, 2000.0]},
	"procedural": {"waves_base": 3, "waves_per_stage": 0.5, "waves_max": 5, "wave_delay_s": 4.0,
		"yaw_half_arc_base_deg": 30.0, "yaw_half_arc_per_stage_deg": 10.0, "yaw_half_arc_max_deg": 75.0,
		"par_time_base_s": 70.0, "par_time_per_stage_s": 10.0},
}
const ENEMIES: Dictionary = {
	"drone": {"threat_cost": 2.0, "first_stage": 1, "group_size": [8, 20]},
	"fighter": {"threat_cost": 8.0, "first_stage": 1, "group_size": [1, 3]},
	"bomber": {"threat_cost": 20.0, "first_stage": 3, "group_size": [1, 2], "spawn": {"pitch_deg": [16.0, 24.0]}},
	"boss": {"threat_cost": 0.0, "first_stage": 1, "group_size": [1, 1]},
}

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345


func _cost(groups: Array[Dictionary]) -> float:
	var total: float = 0.0
	for group: Dictionary in groups:
		total += float(ENEMIES[group["enemy"]]["threat_cost"]) * int(group["count"])
	return total


func test_threat_budget_follows_the_formula() -> void:
	assert_almost_eq(WaveDirector.threat_budget(1, DIRECTOR), 100.0, 0.001)
	assert_almost_eq(WaveDirector.threat_budget(2, DIRECTOR), 118.0, 0.001)
	assert_almost_eq(WaveDirector.threat_budget(5, DIRECTOR), 100.0 * pow(1.18, 4), 0.001)
	assert_almost_eq(WaveDirector.threat_budget(1, DIRECTOR, 1.2), 120.0, 0.001)


func test_enemy_pool_respects_first_stage_and_skips_bosses() -> void:
	assert_eq(WaveDirector.enemy_pool(1, ENEMIES), ["drone", "fighter"] as Array[String])
	assert_eq(WaveDirector.enemy_pool(3, ENEMIES), ["bomber", "drone", "fighter"] as Array[String])


func test_compose_never_overspends_and_uses_most_of_the_budget() -> void:
	for budget: float in [10.0, 100.0, 139.0, 500.0]:
		var groups: Array[Dictionary] = WaveDirector.compose(budget, WaveDirector.enemy_pool(3, ENEMIES), ENEMIES, _rng)
		var cost: float = _cost(groups)
		assert_lte(cost, budget, "budget %s" % budget)
		assert_gt(cost, budget - 2.0, "less than the cheapest enemy is left of %s" % budget)


func test_compose_with_nothing_affordable_is_empty() -> void:
	assert_eq(WaveDirector.compose(1.0, WaveDirector.enemy_pool(3, ENEMIES), ENEMIES, _rng).size(), 0)
	assert_eq(WaveDirector.compose(100.0, [] as Array[String], ENEMIES, _rng).size(), 0)


func test_group_sizes_stay_inside_the_enemy_range() -> void:
	var groups: Array[Dictionary] = WaveDirector.compose(1000.0, ["fighter"] as Array[String], ENEMIES, _rng)
	for group: Dictionary in groups:
		assert_between(int(group["count"]), 1, 3)


func test_resolve_wave_combines_explicit_groups_and_budget() -> void:
	var wave: Dictionary = {"groups": [{"enemy": "bomber", "count": 1}, {"enemy": "unknown", "count": 3}], "budget_share": 0.5, "enemies": ["drone"]}
	var groups: Array[Dictionary] = WaveDirector.resolve_wave(wave, 3, 100.0, ENEMIES, _rng)
	assert_eq(groups[0]["enemy"], "bomber")
	var drones: int = 0
	for group: Dictionary in groups:
		assert_ne(group["enemy"], "unknown", "unknown enemies are dropped")
		if group["enemy"] == "drone":
			drones += int(group["count"])
	assert_eq(drones, 25, "half of 100 buys 25 drones at cost 2")


func test_spawn_region_priority() -> void:
	var stage: Dictionary = {"spawn_yaw_deg": [-30.0, 30.0]}
	var region: Dictionary = WaveDirector.spawn_region({}, stage, ENEMIES["bomber"], DIRECTOR)
	assert_eq(region["yaw_deg"], [-30.0, 30.0], "yaw from the stage")
	assert_eq(region["pitch_deg"], [16.0, 24.0], "pitch from the enemy")
	assert_eq(region["distance_m"], [1200.0, 2000.0], "distance from the director defaults")
	region = WaveDirector.spawn_region({"spawn": {"yaw_deg": [-5.0, 5.0]}}, stage, ENEMIES["bomber"], DIRECTOR)
	assert_eq(region["yaw_deg"], [-5.0, 5.0], "the group wins")


func test_random_point_is_inside_the_region() -> void:
	var region: Dictionary = {"yaw_deg": [-30.0, 30.0], "pitch_deg": [10.0, 20.0], "distance_m": [500.0, 600.0]}
	for attempt: int in 50:
		var point: Vector3 = WaveDirector.random_point(region, _rng)
		assert_between(point.x, -30.0, 30.0)
		assert_between(point.y, 10.0, 20.0)
		assert_between(point.z, 500.0, 600.0)


func test_procedural_stages_grow() -> void:
	var early: Dictionary = WaveDirector.procedural_stage(1, DIRECTOR, ENEMIES)
	var late: Dictionary = WaveDirector.procedural_stage(11, DIRECTOR, ENEMIES)
	assert_eq((early["waves"] as Array).size(), 3)
	assert_eq((late["waves"] as Array).size(), 5, "capped by waves_max")
	assert_eq(early["spawn_yaw_deg"], [-30.0, 30.0])
	assert_eq(late["spawn_yaw_deg"], [-75.0, 75.0], "capped by yaw_half_arc_max_deg")
	assert_gt(float(late["par_time_s"]), float(early["par_time_s"]))
	var share: float = 0.0
	for wave: Dictionary in late["waves"]:
		share += float(wave["budget_share"])
	assert_almost_eq(share, 1.0, 0.0001)


func test_stage_stats_percentages() -> void:
	var stats: StageStats = StageStats.new()
	assert_eq(stats.accuracy_percent(), 0.0)
	stats.shots_fired = 10
	stats.shots_hit = 6
	assert_almost_eq(stats.accuracy_percent(), 60.0, 0.0001)
	stats.shots_hit = 30
	assert_eq(stats.accuracy_percent(), 100.0, "splash hits cannot push accuracy over 100")
	stats.hull_max = 200.0
	stats.hull_end = 50.0
	assert_almost_eq(stats.hull_percent(), 25.0, 0.0001)


func test_module_list_matches_the_registry() -> void:
	var from_registry: Array = BehaviourRegistry.MODULES.keys()
	from_registry.sort()
	var listed: Array = Array(BehaviourModules.IMPLEMENTED)
	listed.sort()
	assert_eq(listed, from_registry)


func test_shipped_stages_only_buy_what_they_can_field() -> void:
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var director: Dictionary = GameData.loader.get_config("director")
	assert_gte(GameData.loader.get_category("stages").size(), 3)
	for number: int in [1, 2, 3]:
		var stage: Dictionary = GameData.loader.get_entry("stages", "stage_%02d" % number)
		assert_false(stage.is_empty(), "stage %d exists" % number)
		var budget: float = WaveDirector.threat_budget(number, director)
		for wave: Dictionary in stage["waves"]:
			var groups: Array[Dictionary] = WaveDirector.resolve_wave(wave, number, budget, enemies, _rng)
			assert_gt(groups.size(), 0, "stage %d has no empty wave" % number)


func test_later_stages_have_bigger_budgets() -> void:
	var director: Dictionary = GameData.loader.get_config("director")
	assert_gt(WaveDirector.threat_budget(2, director), WaveDirector.threat_budget(1, director))
	assert_gt(WaveDirector.threat_budget(3, director), WaveDirector.threat_budget(2, director))
