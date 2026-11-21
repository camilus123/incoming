class_name StageManager
extends Node
## Runs the stages: intro, waves, completion and game over.
##
## Stage data comes from data/stages (authored) or from [WaveDirector]
## (generated). Until the shop exists (M4) the turret is fully repaired and
## re-armed at the start of every stage.

signal state_changed(state: State)

enum State { IDLE, INTRO, RUNNING, COMPLETE, GAME_OVER }

const GROUP: StringName = &"stage_manager"
const ACTION_CONFIRM: StringName = &"confirm"
const ACTION_RETRY: StringName = &"retry"
const AUTO_ADVANCE_S: float = 3.0

var state: State = State.IDLE
var stage_number: int = 1
var stage_data: Dictionary = {}
var stats: StageStats = StageStats.new()
## Index of the wave that is spawning or was spawned last (0-based).
var wave_index: int = 0
## Continue past result screens without input (automated demo).
var auto_advance: bool = false

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


## Starts (or restarts) a stage from a clean field.
func start_stage(number: int) -> void:
	stage_number = maxi(1, number)
	_director = GameData.loader.get_config("director")
	var difficulty_config: Dictionary = GameData.loader.get_config("difficulty")
	_difficulty = (difficulty_config.get("levels", {}) as Dictionary).get(difficulty_config.get("default", "normal"), {})
	stage_data = GameData.loader.get_entry("stages", "stage_%02d" % stage_number)
	if stage_data.is_empty():
		stage_data = WaveDirector.procedural_stage(stage_number, _director, GameData.loader.get_category("enemies"))
	_stage_budget = WaveDirector.threat_budget(stage_number, _director, _difficulty.get("threat_budget_mult", 1.0))

	_enemies.clear_all()
	_enemies.difficulty = _difficulty
	_turret.restore_for_stage()
	stats = StageStats.new()
	stats.stage = stage_number
	stats.hull_max = _turret.max_hull
	stats.hull_end = _turret.hull
	wave_index = 0
	_wave_started = false
	_spawn_queue.clear()
	_wave_delay_left_s = float((stage_data["waves"] as Array)[0].get("delay_s", 0.0))
	_set_state(State.INTRO)
	EventBus.stage_started.emit(stage_number)


func _process(delta_s: float) -> void:
	_state_time_s += delta_s
	match state:
		State.INTRO:
			if _state_time_s >= float(_director.get("intro_s", 3.0)):
				_set_state(State.RUNNING)
		State.RUNNING:
			stats.time_s += delta_s
			_update_waves(delta_s)
		State.COMPLETE:
			if auto_advance and _state_time_s >= AUTO_ADVANCE_S:
				start_stage(stage_number + 1)
		State.GAME_OVER:
			if auto_advance and _state_time_s >= AUTO_ADVANCE_S:
				start_stage(stage_number)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.COMPLETE and event.is_action_pressed(ACTION_CONFIRM):
		start_stage(stage_number + 1)
	elif state == State.GAME_OVER:
		if event.is_action_pressed(ACTION_RETRY):
			start_stage(stage_number)
		elif event.is_action_pressed(ACTION_CONFIRM):
			start_stage(1)


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
		_enemies.spawn_enemy(entry["enemy"], entry["position"], wave_index)
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
	for group: Dictionary in WaveDirector.resolve_wave(wave, stage_number, _stage_budget, enemies, _rng):
		var enemy: Dictionary = enemies[group["enemy"]]
		var region: Dictionary = WaveDirector.spawn_region(group, stage_data, enemy, _director)
		var point: Vector3 = WaveDirector.random_point(region, _rng)
		var centre: Vector3 = origin + _turret.global_transform.basis * TurretAim.direction_from(point.x, point.y) * point.z
		for index: int in int(group["count"]):
			var offset: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1.0, 1.0)) * spread_m
			var position: Vector3 = centre + (offset if int(group["count"]) > 1 else Vector3.ZERO)
			position.y = maxf(position.y, min_altitude_m)
			_spawn_queue.append({"enemy": group["enemy"], "position": position, "time_s": time_s})
			time_s += interval_s
	_wave_spawned_count = _spawn_queue.size()
	EventBus.wave_started.emit(stage_number, wave_index + 1)


func _complete_stage() -> void:
	stats.hull_end = _turret.hull
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
