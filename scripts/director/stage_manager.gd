class_name StageManager
extends Node
## Runs the game loop: shop, stage intro, waves, rewards and game over.
##
## shop -> intro -> running -> complete (rewards) -> shop -> ...
## Stage data comes from data/stages (authored) or from [WaveDirector]
## (generated). The run itself (credits, upgrades, hull) lives in [GameState];
## it is saved every time the shop opens.

signal state_changed(state: State)

enum State { IDLE, SHOP, INTRO, RUNNING, COMPLETE, GAME_OVER }

const GROUP: StringName = &"stage_manager"
const ACTION_CONFIRM: StringName = &"confirm"
const ACTION_RETRY: StringName = &"retry"
const AUTO_ADVANCE_S: float = 3.0

var state: State = State.IDLE
var stage_number: int = 1
var stage_data: Dictionary = {}
var stats: StageStats = StageStats.new()
## Itemised reward of the stage just completed (see [RewardCalculator]).
var reward_lines: Array[Dictionary] = []
## Index of the wave that is spawning or was spawned last (0-based).
var wave_index: int = 0
## Continue past result screens and the shop without input (automated demo).
var auto_advance: bool = false
## With auto_advance: buy every affordable upgrade in the shop first.
var auto_buy: bool = false
## With auto_advance: how long the shop stays open.
var auto_shop_s: float = 1.5

var _turret: Turret
var _enemies: EnemyManager
var _director: Dictionary = {}
var _difficulty: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state_time_s: float = 0.0
var _wave_delay_left_s: float = 0.0
var _wave_started: bool = false
var _wave_spawned_count: int = 0
var _since_wave_spawned_s: float = 0.0
var _spawn_queue: Array[Dictionary] = []
var _spawn_clock_s: float = 0.0
var _stage_budget: float = 0.0
var _auto_bought: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_rng.randomize()
	_turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	_enemies = get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	EventBus.weapon_fired.connect(func(_slot: StringName) -> void: stats.shots_fired += 1)
	EventBus.target_hit.connect(func(_slot: StringName, _killed: bool) -> void: stats.shots_hit += 1)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_projectile_intercepted.connect(func(_id: StringName) -> void: stats.intercepts += 1)
	EventBus.turret_destroyed.connect(_on_turret_destroyed)
	EventBus.shield_broken.connect(func() -> void: stats.shield_broken = true)


## Number of waves in the current stage.
func get_wave_count() -> int:
	return (stage_data.get("waves", []) as Array).size()


## Seconds the current state has been active (for banners and fades).
func get_state_time() -> float:
	return _state_time_s


## Data of a stage: the authored file, or a generated stage beyond those.
func get_stage_data(number: int) -> Dictionary:
	var data: Dictionary = GameData.loader.get_entry("stages", "stage_%02d" % number)
	if data.is_empty():
		data = WaveDirector.procedural_stage(number, GameData.loader.get_config("director"), GameData.loader.get_category("enemies"), GameData.loader.get_category("stages").size())
	return data


## Opens the shop before the run's next stage and autosaves.
func open_shop() -> void:
	_enemies.clear_all()
	GameState.save_run()
	stage_number = GameState.stage
	stage_data = get_stage_data(stage_number)
	_turret.apply_player_state()
	_turret.restore_for_stage()
	_auto_bought = false
	_set_state(State.SHOP)


## Leaves the shop and starts the run's next stage.
func continue_from_shop() -> void:
	if state == State.SHOP:
		start_stage(GameState.stage)


## Starts (or restarts) a stage from a clean field.
func start_stage(number: int) -> void:
	_begin_stage(maxi(1, number), get_stage_data(maxi(1, number)))


## Starts a stage from data that is not part of the campaign (the benchmark).
## `spawn_seed` makes the spawn positions the same on every run.
func start_custom_stage(custom_data: Dictionary, spawn_seed: int) -> void:
	_rng.seed = spawn_seed
	_begin_stage(maxi(1, int(custom_data.get("stage", 1))), custom_data)


func _begin_stage(number: int, data: Dictionary) -> void:
	stage_number = number
	_director = GameData.loader.get_config("director")
	_difficulty = GameState.get_difficulty()
	stage_data = data
	_stage_budget = WaveDirector.threat_budget(stage_number, _director, _difficulty.get("threat_budget_mult", 1.0))

	_enemies.clear_all()
	_enemies.difficulty = _difficulty
	_enemies.prewarm(stage_data)
	_turret.apply_player_state()
	_turret.restore_for_stage()
	stats = StageStats.new()
	stats.stage = stage_number
	stats.hull_max = _turret.max_hull
	stats.hull_end = _turret.hull
	reward_lines = []
	wave_index = 0
	_wave_started = false
	_spawn_queue.clear()
	_wave_delay_left_s = float((stage_data["waves"] as Array)[0].get("delay_s", 0.0))
	_set_state(State.INTRO)
	EventBus.stage_started.emit(stage_number)


func _process(delta_s: float) -> void:
	_state_time_s += delta_s
	match state:
		State.SHOP:
			if auto_advance and auto_buy and not _auto_bought:
				_auto_bought = true
				_buy_everything_affordable()
			if auto_advance and _state_time_s >= auto_shop_s:
				continue_from_shop()
		State.INTRO:
			if _state_time_s >= float(_director.get("intro_s", 3.0)):
				_set_state(State.RUNNING)
		State.RUNNING:
			stats.time_s += delta_s
			_update_waves(delta_s)
		State.COMPLETE:
			if auto_advance and _state_time_s >= AUTO_ADVANCE_S:
				open_shop()
		State.GAME_OVER:
			if auto_advance and _state_time_s >= AUTO_ADVANCE_S:
				_retry_from_save()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.COMPLETE and event.is_action_pressed(ACTION_CONFIRM):
		open_shop()
	elif state == State.GAME_OVER:
		if event.is_action_pressed(ACTION_RETRY):
			_retry_from_save()
		elif event.is_action_pressed(ACTION_CONFIRM):
			GameState.new_run()
			open_shop()


## Back to the last autosave: the shop before the stage that was lost.
func _retry_from_save() -> void:
	if not GameState.load_run():
		# No save (non-persistent run): keep the upgrades, repair, try again.
		GameState.hull = -1.0
	open_shop()


func _buy_everything_affordable() -> void:
	# Weapons first, then core systems, then shields: a build that can kill things.
	var order: Array[String] = GameState.tree.get_node_ids().duplicate()
	var priority: Callable = func(id: String) -> int:
		var branch: String = GameState.tree.get_node(id).get("branch", "")
		return 0 if branch.begins_with("primary") else (1 if branch == "alternate" else (2 if branch == "core" else 3))
	order.sort_custom(func(a: String, b: String) -> bool: return priority.call(a) < priority.call(b))
	var bought: bool = true
	while bought:
		bought = false
		for id: String in order:
			if GameState.buy(id):
				bought = true
	GameState.repair_hull()
	# Use what was bought: the most expensive owned weapon in each slot.
	for slot: String in GameState.SLOTS:
		var best: String = ""
		var best_cost: int = -1
		for id: String in GameState.purchased:
			for effect: Dictionary in GameState.tree.get_node(id).get("effects", []):
				var weapon_id: String = effect.get("unlock", "")
				# The bot cannot judge lead or time a charge the way a player can, so it
				# sticks to weapons it can simply hold on target.
				var is_slow: bool = slot == "primary" and GameData.loader.get_entry("weapons", weapon_id).get("archetype", "") in ["projectile", "airburst", "charge_pierce"]
				if GameState.can_equip(slot, weapon_id) and not is_slow and GameState.tree.get_cost(id) > best_cost:
					best = weapon_id
					best_cost = GameState.tree.get_cost(id)
		if not best.is_empty():
			GameState.equip(slot, best)


func _update_waves(delta_s: float) -> void:
	if not _wave_started:
		_wave_delay_left_s -= delta_s
		if _wave_delay_left_s > 0.0:
			return
		_begin_wave()

	# Spawn everything that is due.
	_spawn_clock_s += delta_s
	while not _spawn_queue.is_empty() and float(_spawn_queue[0]["time_s"]) <= _spawn_clock_s:
		var entry: Dictionary = _spawn_queue.pop_front()
		_enemies.spawn_enemy(entry["enemy"], entry["position"], wave_index, entry["scale"])
	if not _spawn_queue.is_empty():
		return

	var is_last_wave: bool = wave_index >= get_wave_count() - 1
	if is_last_wave:
		if _enemies.get_enemy_count() == 0 and _enemies.get_projectile_count() == 0:
			_complete_stage()
		return
	# Start the next wave once most of this one is gone, or after a timeout.
	_since_wave_spawned_s += delta_s
	var cleared_enough: bool = _enemies.get_wave_count(wave_index) <= int(floor(_wave_spawned_count * float(_director.get("wave_clear_fraction", 0.25))))
	if cleared_enough or _since_wave_spawned_s >= float(_director.get("wave_timeout_s", 28.0)):
		wave_index += 1
		_wave_started = false
		_wave_delay_left_s = float((stage_data["waves"] as Array)[wave_index].get("delay_s", 0.0))


## Debug menu: ends the running stage as if everything had been destroyed
## (no bounties for what was skipped).
func debug_skip_stage() -> void:
	if state != State.INTRO and state != State.RUNNING:
		return
	_enemies.clear_all()
	_spawn_queue.clear()
	if state == State.INTRO:
		_set_state(State.RUNNING)
	_complete_stage()


func _begin_wave() -> void:
	_wave_started = true
	_since_wave_spawned_s = 0.0
	_spawn_clock_s = 0.0
	_spawn_queue.clear()
	var wave: Dictionary = (stage_data["waves"] as Array)[wave_index]
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var origin: Vector3 = _turret.get_aim_transform().origin
	var interval_s: float = _director.get("spawn_interval_s", 0.12)
	var spread_m: float = _director.get("group_spread_m", 70.0)
	var min_altitude_m: float = _director.get("min_spawn_altitude_m", 40.0)
	var time_s: float = 0.0
	var stage_scale: Dictionary = stage_data.get("enemy_scale", {})
	for group: Dictionary in WaveDirector.resolve_wave(wave, stage_number, _stage_budget, enemies, _rng):
		var enemy: Dictionary = enemies[group["enemy"]]
		# A group's own scale (bosses) multiplies with the stage's (endless mode).
		var group_scale: Dictionary = group.get("scale", {})
		var scale: Dictionary = {
			"hp": float(stage_scale.get("hp", 1.0)) * float(group_scale.get("hp", 1.0)),
			"damage": float(stage_scale.get("damage", 1.0)) * float(group_scale.get("damage", 1.0)),
		}
		var region: Dictionary = WaveDirector.spawn_region(group, stage_data, enemy, _director)
		var point: Vector3 = WaveDirector.random_point(region, _rng)
		var centre: Vector3 = origin + _turret.global_transform.basis * TurretAim.direction_from(point.x, point.y) * point.z
		for index: int in int(group["count"]):
			var offset: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1.0, 1.0)) * spread_m
			var position: Vector3 = centre + (offset if int(group["count"]) > 1 else Vector3.ZERO)
			position.y = maxf(position.y, min_altitude_m)
			_spawn_queue.append({"enemy": group["enemy"], "position": position, "time_s": time_s, "scale": scale})
			time_s += interval_s
	_wave_spawned_count = _spawn_queue.size()
	EventBus.wave_started.emit(stage_number, wave_index + 1)


## The stage is won: work out the reward and advance the run.
func _complete_stage() -> void:
	stats.hull_end = _turret.hull
	reward_lines = RewardCalculator.calculate(stats, stage_data, GameData.loader.get_config("economy"), _difficulty.get("reward_mult", 1.0))
	GameState.hull = _turret.hull
	GameState.stage = stage_number + 1
	GameState.statistics["stages_cleared"] = int(GameState.statistics.get("stages_cleared", 0)) + 1
	GameState.statistics["kills"] = int(GameState.statistics.get("kills", 0)) + stats.kills
	GameState.add_credits(RewardCalculator.total(reward_lines))
	_set_state(State.COMPLETE)
	EventBus.stage_completed.emit(stage_number)


func _on_enemy_killed(_enemy_id: StringName, bounty: int) -> void:
	stats.kills += 1
	stats.bounty += bounty


func _on_turret_destroyed() -> void:
	if state == State.GAME_OVER:
		return
	stats.hull_end = 0.0
	_set_state(State.GAME_OVER)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time_s = 0.0
	state_changed.emit(state)
