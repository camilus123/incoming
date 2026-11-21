class_name AutoDemo
extends Node
## Automated test drive of the turret, started with `++ --auto-demo`.
##
## Aims at each target in turn, holds the primary trigger, fires missile
## salvos, pushes the aim into the yaw limit, then prints frame statistics and
## quits. Used to check a build and to take screenshots without a player.
##
## Options (after `++`):
##   --demo-seconds=N        run time (default 16)
##   --screenshot-dir=PATH   save PNG screenshots there
##   --demo-stages=N         also stop once stage N is completed
##   --demo-speed=X          run the game X times faster (for quick checks, not for fps)
##   --demo-power            step the power split every 2 s and print its effects

const WARMUP_S: float = 2.0
const AIM_SPEED_DEG_S: float = 160.0
const DWELL_S: float = 1.3
const SCREENSHOT_TIMES_S: PackedFloat32Array = [3.0, 6.5, 10.0]

var turret: Turret

var _duration_s: float = 16.0
var _screenshot_dir: String = ""
var _time_s: float = 0.0
var _target_index: int = 0
var _dwell_left_s: float = DWELL_S
var _next_screenshot: int = 0
var _frame_times_ms: PackedFloat32Array = []
var _last_tick_usec: int = 0
var _finished: bool = false
var _stop_after_stage: int = 0
var _cycle_power: bool = false
var _power_timer_s: float = 0.0
var _power_direction: int = 1


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-seconds="):
			_duration_s = argument.trim_prefix("--demo-seconds=").to_float()
		elif argument.begins_with("--demo-speed="):
			Engine.time_scale = maxf(0.1, argument.trim_prefix("--demo-speed=").to_float())
		elif argument.begins_with("--demo-stages="):
			_stop_after_stage = argument.trim_prefix("--demo-stages=").to_int()
		elif argument.begins_with("--screenshot-dir="):
			_screenshot_dir = argument.trim_prefix("--screenshot-dir=")
	turret.player_input_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_last_tick_usec = Time.get_ticks_usec()
	EventBus.stage_completed.connect(_on_stage_ended.bind("COMPLETE"))
	_cycle_power = OS.get_cmdline_user_args().has("--demo-power")
	if OS.get_cmdline_user_args().has("--demo-log-damage"):
		EventBus.hull_damaged.connect(func(amount: float, remaining: float) -> void: print("DAMAGE t=%.1f amount=%.1f hull=%.0f" % [_time_s, amount, remaining]))
	EventBus.turret_destroyed.connect(_on_stage_ended.bind(0, "GAME_OVER"))


func _process(delta_s: float) -> void:
	if _finished:
		return
	var now_usec: int = Time.get_ticks_usec()
	if _time_s >= WARMUP_S:
		_frame_times_ms.append(float(now_usec - _last_tick_usec) / 1000.0)
	_last_tick_usec = now_usec
	_time_s += delta_s

	if _cycle_power:
		_update_power_cycle(delta_s)
	var edge_phase: bool = _time_s > _duration_s - 3.0
	if edge_phase:
		# Push into the right-hand yaw limit to exercise the arc clamp.
		turret.aim.apply_input(AIM_SPEED_DEG_S * delta_s, 0.0)
		turret.set_trigger(Turret.SLOT_PRIMARY, false)
	else:
		_track_targets(delta_s)
	# Hold the missile trigger for 1.6 s out of every 4 s, releasing fires the salvo.
	turret.set_trigger(Turret.SLOT_ALTERNATE, not edge_phase and fmod(_time_s, 4.0) < 1.6)

	if _next_screenshot < SCREENSHOT_TIMES_S.size() and _time_s >= SCREENSHOT_TIMES_S[_next_screenshot]:
		_save_screenshot("demo_%d" % _next_screenshot)
		_next_screenshot += 1
	if _time_s >= _duration_s:
		_finish()


func _track_targets(delta_s: float) -> void:
	var target: CombatTarget = _pick_target()
	if target == null:
		turret.set_trigger(Turret.SLOT_PRIMARY, false)
		return
	var wanted: Vector2 = turret.get_aim_angles_to(target.get_aim_point())
	var step: float = AIM_SPEED_DEG_S * delta_s
	var yaw_error: float = wanted.x - turret.aim.yaw_deg
	var pitch_error: float = wanted.y - turret.aim.pitch_deg
	turret.aim.apply_input(clampf(yaw_error, -step, step), clampf(pitch_error, -step, step))
	turret.set_trigger(Turret.SLOT_PRIMARY, absf(yaw_error) < 0.3 and absf(pitch_error) < 0.3)


## In a stage: the closest live threat inside the aim arc. On the test range
## (static dummies): each dummy in turn.
func _pick_target() -> CombatTarget:
	var targets: Array[Node] = get_tree().get_nodes_in_group(CombatTarget.GROUP)
	if targets.is_empty():
		return null
	if targets[0] is TargetDummy:
		_dwell_left_s -= get_process_delta_time()
		var dummy: CombatTarget = targets[_target_index % targets.size()] as CombatTarget
		if _dwell_left_s <= 0.0 or not dummy.is_alive():
			_target_index += 1
			_dwell_left_s = DWELL_S + 1.0
		return dummy
	var origin: Vector3 = turret.get_aim_transform().origin
	var best: CombatTarget = null
	var best_distance: float = INF
	for node: Node in targets:
		var target: CombatTarget = node as CombatTarget
		if target == null or not target.is_alive():
			continue
		var angles: Vector2 = turret.get_aim_angles_to(target.get_aim_point())
		if angles.x < turret.aim.yaw_min_deg or angles.x > turret.aim.yaw_max_deg or angles.y < turret.aim.pitch_min_deg or angles.y > turret.aim.pitch_max_deg:
			continue
		var distance: float = origin.distance_squared_to(target.get_aim_point())
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


## Walks the power split up and down and prints what each step does.
func _update_power_cycle(delta_s: float) -> void:
	_power_timer_s += delta_s
	if _power_timer_s < 2.0:
		return
	_power_timer_s = 0.0
	if not turret.shift_power(_power_direction):
		_power_direction = -_power_direction
		turret.shift_power(_power_direction)
	var weapon: Weapon = turret.get_weapon(Turret.SLOT_PRIMARY)
	print("POWER shield_share=%.1f recharge_per_s=%.1f weapon_output=%.2f primary_damage=%.2f shield=%.0f" % [
		turret.power.shield_share,
		turret.shield.recharge_per_s * turret.power.shield_recharge_multiplier(),
		turret.power.weapon_output_multiplier(),
		float(weapon.data.get("damage", 0.0)) * turret.power.weapon_output_multiplier(),
		turret.shield.charge])


func _on_stage_ended(stage: int, result: String) -> void:
	var stages: StageManager = get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
	if stages == null:
		return
	var stats: StageStats = stages.stats
	print("STAGE_RESULT stage=%d result=%s time_s=%.1f kills=%d intercepts=%d accuracy=%d hull=%d" % [
		stages.stage_number, result, stats.time_s, stats.kills, stats.intercepts,
		roundi(stats.accuracy_percent()), roundi(turret.hull)])
	if result == "COMPLETE" and _stop_after_stage > 0 and stage >= _stop_after_stage:
		_finish()

func _save_screenshot(file_name: String) -> void:
	if _screenshot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_screenshot_dir)
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_dir.path_join(file_name + ".png"))


func _finish() -> void:
	_finished = true
	await _save_screenshot("demo_edge")
	var window_size: Vector2i = get_tree().root.size
	if _frame_times_ms.is_empty():
		print("PERF no frames recorded")
	else:
		var total_ms: float = 0.0
		for frame_ms: float in _frame_times_ms:
			total_ms += frame_ms
		var sorted: PackedFloat32Array = _frame_times_ms.duplicate()
		sorted.sort()
		var worst_count: int = maxi(1, sorted.size() / 100)
		var worst_ms: float = 0.0
		for index: int in range(sorted.size() - worst_count, sorted.size()):
			worst_ms += sorted[index]
		print("PERF resolution=%dx%d frames=%d avg_fps=%.1f low1_fps=%.1f max_frame_ms=%.2f" % [
			window_size.x, window_size.y, sorted.size(),
			1000.0 * sorted.size() / total_ms,
			1000.0 * worst_count / worst_ms,
			sorted[sorted.size() - 1]])
	get_tree().quit()
