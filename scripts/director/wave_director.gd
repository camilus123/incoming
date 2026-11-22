class_name WaveDirector
extends RefCounted
## Decides what a stage throws at the player. Pure logic, unit tested.
##
## A stage has a threat budget: `base_budget * growth^(stage - 1)`. Each wave
## may list explicit enemy groups and/or take a share of the budget, which
## the director spends on enemy types from the wave's list. Stages beyond the
## authored ones are generated with the same rules.


## Threat budget of a stage. `director` is the "director" config.
static func threat_budget(stage: int, director: Dictionary, difficulty_multiplier: float = 1.0) -> float:
	var base: float = director.get("base_budget", 100.0)
	var growth: float = director.get("growth", 1.18)
	return base * pow(growth, maxi(stage, 1) - 1) * difficulty_multiplier


## Ids of all enemy types the director may buy at `stage`, sorted by id.
## Types without a threat cost (bosses) are never bought.
static func enemy_pool(stage: int, enemies: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		if int(enemy.get("first_stage", 1)) <= stage and float(enemy.get("threat_cost", 0.0)) > 0.0:
			pool.append(enemy_id)
	pool.sort()
	return pool


## Spends `budget` on groups of enemies from `pool`.
## Returns a list of `{ "enemy": id, "count": n, "spawn": {} }`.
static func compose(budget: float, pool: Array[String], enemies: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var remaining: float = budget
	for attempt: int in 200:
		var affordable: Array[String] = []
		for enemy_id: String in pool:
			if enemies.has(enemy_id) and float(enemies[enemy_id]["threat_cost"]) <= remaining:
				affordable.append(enemy_id)
		if affordable.is_empty():
			break
		var chosen: String = affordable[rng.randi_range(0, affordable.size() - 1)]
		var enemy: Dictionary = enemies[chosen]
		var cost: float = enemy["threat_cost"]
		var size_range: Array = enemy.get("group_size", [1, 1])
		var count: int = rng.randi_range(int(size_range[0]), maxi(int(size_range[0]), int(size_range[1])))
		count = clampi(count, 1, int(floor(remaining / cost)))
		groups.append({"enemy": chosen, "count": count, "spawn": {}})
		remaining -= cost * count
	return groups


## All groups of one wave: its explicit groups plus what its budget share buys.
static func resolve_wave(wave: Dictionary, stage: int, stage_budget: float, enemies: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for group: Dictionary in wave.get("groups", []):
		if enemies.has(group["enemy"]):
			groups.append(group)
	var share: float = wave.get("budget_share", 0.0)
	if share > 0.0:
		var pool: Array[String] = []
		for enemy_id: String in wave.get("enemies", []):
			if enemies.has(enemy_id):
				pool.append(enemy_id)
		if pool.is_empty():
			pool = enemy_pool(stage, enemies)
		groups.append_array(compose(stage_budget * share, pool, enemies, rng))
	return groups


## Where a group spawns: `{ yaw_deg, pitch_deg, distance_m }`, each a [min, max]
## pair. The group's own settings win, then the enemy type's (a boss comes
## from dead ahead), then the stage's yaw arc, then the director defaults.
static func spawn_region(group: Dictionary, stage_data: Dictionary, enemy: Dictionary, director: Dictionary) -> Dictionary:
	var defaults: Dictionary = director.get("default_spawn", {})
	var group_spawn: Dictionary = group.get("spawn", {})
	var enemy_spawn: Dictionary = enemy.get("spawn", {})
	return {
		"yaw_deg": group_spawn.get("yaw_deg", enemy_spawn.get("yaw_deg", stage_data.get("spawn_yaw_deg", defaults.get("yaw_deg", [-60.0, 60.0])))),
		"pitch_deg": group_spawn.get("pitch_deg", enemy_spawn.get("pitch_deg", defaults.get("pitch_deg", [8.0, 40.0]))),
		"distance_m": group_spawn.get("distance_m", enemy_spawn.get("distance_m", defaults.get("distance_m", [1200.0, 2000.0]))),
	}


## A random point in a spawn region as Vector3(yaw_deg, pitch_deg, distance_m).
static func random_point(region: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	return Vector3(_in_range(region["yaw_deg"], rng), _in_range(region["pitch_deg"], rng), _in_range(region["distance_m"], rng))


## Builds the data of a stage that has no authored file (endless mode).
## `authored_count` is the number of authored stages: enemies get tougher for
## every stage beyond them, and every `boss.every`-th stage is a boss stage
## with a scaled-up boss and a reduced escort.
static func procedural_stage(stage: int, director: Dictionary, enemies: Dictionary, authored_count: int = 0) -> Dictionary:
	var rules: Dictionary = director.get("procedural", {})
	var beyond: int = maxi(0, stage - authored_count)
	var enemy_scale: Dictionary = {
		"hp": 1.0 + float(rules.get("enemy_hp_growth_per_stage", 0.0)) * beyond,
		"damage": 1.0 + float(rules.get("enemy_damage_growth_per_stage", 0.0)) * beyond,
	}
	var boss_rules: Dictionary = rules.get("boss", {})
	var boss_id: String = boss_rules.get("enemy", "")
	var is_boss_stage: bool = enemies.has(boss_id) and stage % maxi(1, int(boss_rules.get("every", 5))) == 0
	var wave_count: int = mini(int(rules.get("waves_max", 8)), int(rules.get("waves_base", 3)) + int(floor(float(rules.get("waves_per_stage", 0.3)) * (stage - 1))))
	var half_arc: float = minf(rules.get("yaw_half_arc_max_deg", 75.0), float(rules.get("yaw_half_arc_base_deg", 30.0)) + float(rules.get("yaw_half_arc_per_stage_deg", 7.0)) * (stage - 1))
	var pool: Array[String] = enemy_pool(stage, enemies)
	var waves: Array[Dictionary] = []
	var total_share: float = float(boss_rules.get("escort_budget_share", 0.5)) if is_boss_stage else 1.0
	for index: int in wave_count:
		waves.append({
			"delay_s": rules.get("wave_delay_s", 4.0),
			"budget_share": total_share / wave_count,
			"enemies": pool,
			"groups": [],
		})
	if is_boss_stage:
		# Each boss after the last authored one is tougher than the one before.
		var first_scaled: int = boss_rules.get("first_scaled_stage", 10)
		var generation: int = maxi(0, (stage - first_scaled) / maxi(1, int(boss_rules.get("every", 5)))) + 1
		(waves[0]["groups"] as Array).append({"enemy": boss_id, "count": 1, "spawn": {}, "scale": {
			"hp": pow(float(boss_rules.get("hp_growth_per_boss", 1.5)), generation),
			"damage": pow(float(boss_rules.get("damage_growth_per_boss", 1.25)), generation),
		}})
	return {
		"id": "stage_%02d" % stage,
		"stage": stage,
		"boss": is_boss_stage,
		"enemy_scale": enemy_scale,
		"display_name": "Dreadnought" if is_boss_stage else "",
		"briefing": "",
		"time_of_day": "day",
		"par_time_s": float(rules.get("par_time_base_s", 70.0)) + float(rules.get("par_time_per_stage_s", 12.0)) * (stage - 1),
		"spawn_yaw_deg": [-half_arc, half_arc],
		"waves": waves,
	}


static func _in_range(pair: Array, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(float(pair[0]), float(pair[1]))
