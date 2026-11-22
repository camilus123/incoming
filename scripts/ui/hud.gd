extends Control
## In-game HUD: crosshair, weapon heat, missile status, lock brackets, hit
## markers, aim-arc indicators, threat markers, shield and hull bars and the
## power gauge. In debug builds F1 shows the developer read-out (fps, aim,
## power and weapon numbers).
##
## Everything is drawn in `_draw()` in UI units. The project's stretch
## settings scale it with the resolution and keep it centred on any aspect
## ratio, so nothing here depends on the window size.

const COLOR_MAIN: Color = Color(0.6, 0.95, 1.0, 0.9)
const COLOR_DIM: Color = Color(0.6, 0.95, 1.0, 0.35)
const COLOR_WARN: Color = Color(1.0, 0.7, 0.2, 0.95)
const COLOR_ALERT: Color = Color(1.0, 0.25, 0.2, 0.95)
const COLOR_LOCK: Color = Color(1.0, 0.3, 0.25, 0.95)
const COLOR_SHIELD: Color = Color(0.35, 0.75, 1.0, 0.95)
const COLOR_WEAPON: Color = Color(1.0, 0.6, 0.2, 0.95)
## Dark backing under panels and a soft shadow under text, so the HUD stays
## readable against a bright sky or an explosion.
const COLOR_PANEL: Color = Color(0.02, 0.05, 0.08, 0.45)
const COLOR_SHADOW: Color = Color(0.0, 0.02, 0.04, 0.6)
const BAR_SEGMENTS: int = 10
const LOW_HULL_FRACTION: float = 0.3
const HEAT_RADIUS: float = 52.0
const HIT_MARKER_S: float = 0.14
const KILL_MARKER_S: float = 0.35
const MESSAGE_S: float = 2.5
const READY_FLASH_S: float = 1.5
const MAX_EDGE_INDICATORS: int = 14
const EDGE_MARGIN: float = 70.0

var _turret: Turret
var _stages: StageManager
var _enemies: EnemyManager
var _damage_flash: float = 0.0
var _shown_share: float = 0.5
var _power_pulse: float = 0.0
var _shield_flash: float = 0.0
var _show_health_bars: bool = false
var _font: Font
var _hit_left_s: float = 0.0
var _kill_left_s: float = 0.0
var _message: String = ""
var _message_left_s: float = 0.0
var _time_s: float = 0.0
## Reload bar of the alternate weapon: it stays on screen, full, once the
## weapon is ready again, and "READY" flashes for a moment.
var _alternate_reloading: bool = false
var _alternate_ready_at_s: float = -100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	EventBus.target_hit.connect(_on_target_hit)
	EventBus.ui_message.connect(_on_ui_message)
	EventBus.hull_damaged.connect(func(_amount: float, _remaining: float) -> void: _damage_flash = 1.0)
	EventBus.shield_hit.connect(func(_amount: float, _remaining: float) -> void: _shield_flash = 1.0)
	EventBus.power_split_changed.connect(func(_share: float) -> void: _power_pulse = 1.0)
	EventBus.shield_broken.connect(_on_ui_message.bind("SHIELDS DOWN"))


func _process(delta_s: float) -> void:
	if _turret == null:
		_turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
		_stages = get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
		_enemies = get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	_damage_flash = maxf(0.0, _damage_flash - delta_s * 2.5)
	_shield_flash = maxf(0.0, _shield_flash - delta_s * 4.0)
	_power_pulse = maxf(0.0, _power_pulse - delta_s * 3.0)
	if _turret != null:
		_shown_share = lerpf(_shown_share, _turret.power.shield_share, 1.0 - exp(-14.0 * delta_s))
	_time_s += delta_s
	_hit_left_s = maxf(0.0, _hit_left_s - delta_s)
	_kill_left_s = maxf(0.0, _kill_left_s - delta_s)
	_message_left_s = maxf(0.0, _message_left_s - delta_s)
	queue_redraw()


func _draw() -> void:
	if _turret == null or (_stages != null and _stages.state == StageManager.State.SHOP):
		return
	var centre: Vector2 = size * 0.5
	var primary: Weapon = _turret.get_weapon(Turret.SLOT_PRIMARY)
	var alternate: Weapon = _turret.get_weapon(Turret.SLOT_ALTERNATE)

	_draw_damage_flash()
	if _enemies != null:
		_draw_threats(centre)
	if _stages != null:
		_draw_stage_info(centre)
	_draw_crosshair(centre, primary)
	if primary != null:
		_draw_heat_arc(centre, primary, -1.0)
		_draw_charge(centre, primary, 34.0)
	if alternate != null:
		_draw_heat_arc(centre, alternate, 1.0)
		_draw_charge(centre, alternate, 40.0)
		_draw_alternate_status(centre, alternate)
		_draw_locks(alternate)
	_draw_hit_markers(centre)
	_draw_arc_indicator(centre)
	_draw_edge_warnings(centre)
	_draw_hull()
	_draw_power_gauge(centre)
	_draw_messages(centre)
	if Input.is_action_pressed(&"show_intel") and _stages != null and _enemies != null and not get_tree().paused:
		_draw_intel(centre)
	if OS.is_debug_build() and DebugMenu.show_stats:
		_draw_debug()


func _draw_crosshair(centre: Vector2, primary: Weapon) -> void:
	var style: String = "cross"
	if primary != null:
		var visuals: Dictionary = primary.data.get("visuals", {})
		style = visuals.get("crosshair", "cross")
	match style:
		"dot":
			draw_circle(centre, 2.5, COLOR_MAIN)
		"circle":
			draw_arc(centre, 14.0, 0.0, TAU, 40, COLOR_MAIN, 1.5, true)
			draw_circle(centre, 1.5, COLOR_MAIN)
		_:
			for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(centre + direction * 7.0, centre + direction * 18.0, COLOR_MAIN, 2.0, true)
			draw_circle(centre, 1.5, COLOR_MAIN)


## Heat gauge as an arc beside the crosshair: side -1 = left, +1 = right.
func _draw_heat_arc(centre: Vector2, weapon: Weapon, side: float) -> void:
	var half_span: float = deg_to_rad(40.0)
	var middle: float = PI if side < 0.0 else 0.0
	# Both arcs fill from the bottom upwards.
	var bottom: float = middle - half_span * side
	var top: float = middle + half_span * side
	draw_arc(centre, HEAT_RADIUS, bottom, top, 24, COLOR_DIM, 3.0, true)

	var heat: float = weapon.heat.heat
	if heat <= 0.001:
		return
	var color: Color = COLOR_MAIN.lerp(COLOR_WARN, clampf(heat * 1.4, 0.0, 1.0))
	if weapon.heat.overheated:
		color = COLOR_ALERT
		color.a = 0.55 + 0.45 * sin(_time_s * 18.0)
	draw_arc(centre, HEAT_RADIUS, bottom, lerpf(bottom, top, heat), 24, color, 5.0, true)
	if weapon.heat.overheated:
		var text_position: Vector2 = centre + Vector2(side * (HEAT_RADIUS + 14.0), -44.0)
		_text(text_position, "OVERHEAT", 13, COLOR_ALERT, HORIZONTAL_ALIGNMENT_RIGHT if side < 0.0 else HORIZONTAL_ALIGNMENT_LEFT)


func _draw_alternate_status(centre: Vector2, weapon: Weapon) -> void:
	var anchor: Vector2 = centre + Vector2(HEAT_RADIUS + 14.0, 6.0)
	if weapon.ammo != Weapon.UNLIMITED_AMMO:
		var color: Color = COLOR_MAIN if weapon.ammo > 0 else COLOR_ALERT
		_text(anchor, "%d" % weapon.ammo, 18, color, HORIZONTAL_ALIGNMENT_LEFT)
	var reload: float = weapon.get_reload_fraction()
	var bar: Rect2 = Rect2(anchor + Vector2(0.0, 8.0), Vector2(54.0, 4.0))
	if reload > 0.0:
		_alternate_reloading = true
		draw_rect(bar, COLOR_DIM)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - reload), bar.size.y)), COLOR_WARN)
	else:
		if _alternate_reloading:
			_alternate_reloading = false
			_alternate_ready_at_s = _time_s
		var since_ready_s: float = _time_s - _alternate_ready_at_s
		if since_ready_s < READY_FLASH_S and weapon.has_ammo():
			draw_rect(bar, COLOR_MAIN)
			# Blinks three times, then stays away until the next reload.
			if fmod(since_ready_s, READY_FLASH_S / 3.0) < READY_FLASH_S / 6.0:
				_text(anchor + Vector2(0.0, 32.0), "READY", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var progress: float = weapon.get_lock_progress()
	if progress > 0.0:
		draw_arc(centre, 26.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, COLOR_LOCK, 2.0, true)


func _draw_locks(weapon: Weapon) -> void:
	var camera: Camera3D = _turret.rig.get_camera()
	if camera == null:
		return
	var focal: float = (size.y * 0.5) / tan(deg_to_rad(camera.fov) * 0.5)
	var counted: Dictionary = {}
	for target: CombatTarget in weapon.get_lock_targets():
		if not is_instance_valid(target):
			continue
		counted[target] = int(counted.get(target, 0)) + 1
	for target: CombatTarget in counted:
		var point: Vector3 = target.get_aim_point()
		if camera.is_position_behind(point):
			continue
		var screen: Vector2 = camera.unproject_position(point)
		var distance: float = camera.global_position.distance_to(point)
		var half: float = clampf(target.target_radius_m / distance * focal * 1.3, 16.0, 90.0)
		_draw_brackets(screen, half, COLOR_LOCK)
		if counted[target] > 1:
			_text(screen + Vector2(half + 6.0, -half + 4.0), "x%d" % counted[target], 14, COLOR_LOCK, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_brackets(centre: Vector2, half: float, color: Color) -> void:
	var arm: float = half * 0.4
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point: Vector2 = centre + corner * half
		draw_line(point, point - Vector2(corner.x * arm, 0.0), color, 2.0, true)
		draw_line(point, point - Vector2(0.0, corner.y * arm), color, 2.0, true)


func _draw_hit_markers(centre: Vector2) -> void:
	var color: Color
	var reach: float
	if _kill_left_s > 0.0:
		color = COLOR_ALERT
		color.a = _kill_left_s / KILL_MARKER_S
		reach = 20.0
	elif _hit_left_s > 0.0:
		color = Color(1, 1, 1, _hit_left_s / HIT_MARKER_S)
		reach = 14.0
	else:
		return
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_line(centre + corner * 8.0, centre + corner * reach, color, 2.0, true)


## A small map of the aim arc below the crosshair: where the turret points
## inside its yaw and pitch limits.
func _draw_arc_indicator(centre: Vector2) -> void:
	var aim: TurretAim = _turret.aim
	var width: float = 360.0
	var origin: Vector2 = Vector2(centre.x - width * 0.5, size.y - 70.0)
	draw_line(origin, origin + Vector2(width, 0.0), COLOR_DIM, 2.0)
	draw_line(origin + Vector2(0.0, -8.0), origin + Vector2(0.0, 8.0), COLOR_MAIN, 2.0)
	draw_line(origin + Vector2(width, -8.0), origin + Vector2(width, 8.0), COLOR_MAIN, 2.0)
	draw_line(origin + Vector2(width * 0.5, -4.0), origin + Vector2(width * 0.5, 4.0), COLOR_DIM, 1.0)
	var yaw_fraction: float = inverse_lerp(aim.yaw_min_deg, aim.yaw_max_deg, aim.yaw_deg)
	var yaw_color: Color = COLOR_WARN if aim.yaw_edge_factor() != 0.0 else COLOR_MAIN
	var marker: Vector2 = origin + Vector2(width * yaw_fraction, 0.0)
	draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -3), marker + Vector2(-6, -13), marker + Vector2(6, -13)]), yaw_color)
	_text(origin + Vector2(width * 0.5, 26.0), "YAW %+.0f°" % aim.yaw_deg, 13, COLOR_MAIN, HORIZONTAL_ALIGNMENT_CENTER)

	var height: float = 120.0
	var base: Vector2 = Vector2(origin.x + width + 40.0, size.y - 40.0)
	draw_line(base, base + Vector2(0.0, -height), COLOR_DIM, 2.0)
	draw_line(base + Vector2(-8.0, 0.0), base + Vector2(8.0, 0.0), COLOR_MAIN, 2.0)
	draw_line(base + Vector2(-8.0, -height), base + Vector2(8.0, -height), COLOR_MAIN, 2.0)
	var pitch_fraction: float = inverse_lerp(aim.pitch_min_deg, aim.pitch_max_deg, aim.pitch_deg)
	var pitch_color: Color = COLOR_WARN if aim.pitch_edge_factor() != 0.0 else COLOR_MAIN
	var pitch_marker: Vector2 = base + Vector2(0.0, -height * pitch_fraction)
	draw_colored_polygon(PackedVector2Array([pitch_marker + Vector2(3, 0), pitch_marker + Vector2(13, -6), pitch_marker + Vector2(13, 6)]), pitch_color)
	_text(base + Vector2(20.0, -height * 0.5 + 5.0), "PITCH %+.0f°" % aim.pitch_deg, 13, COLOR_MAIN, HORIZONTAL_ALIGNMENT_LEFT)


## Amber bars next to the crosshair that brighten as the aim nears a limit.
func _draw_edge_warnings(centre: Vector2) -> void:
	var aim: TurretAim = _turret.aim
	var yaw_factor: float = aim.yaw_edge_factor()
	if yaw_factor != 0.0:
		var color: Color = COLOR_WARN
		color.a = 0.25 + 0.75 * absf(yaw_factor)
		var x: float = centre.x + signf(yaw_factor) * 150.0
		draw_line(Vector2(x, centre.y - 60.0), Vector2(x, centre.y + 60.0), color, 4.0)
		draw_line(Vector2(x, centre.y - 60.0), Vector2(x - signf(yaw_factor) * 14.0, centre.y - 60.0), color, 4.0)
		draw_line(Vector2(x, centre.y + 60.0), Vector2(x - signf(yaw_factor) * 14.0, centre.y + 60.0), color, 4.0)
	var pitch_factor: float = aim.pitch_edge_factor()
	if pitch_factor != 0.0:
		var color: Color = COLOR_WARN
		color.a = 0.25 + 0.75 * absf(pitch_factor)
		var y: float = centre.y - signf(pitch_factor) * 110.0
		draw_line(Vector2(centre.x - 60.0, y), Vector2(centre.x + 60.0, y), color, 4.0)
		draw_line(Vector2(centre.x - 60.0, y), Vector2(centre.x - 60.0, y + signf(pitch_factor) * 14.0), color, 4.0)
		draw_line(Vector2(centre.x + 60.0, y), Vector2(centre.x + 60.0, y + signf(pitch_factor) * 14.0), color, 4.0)


func _draw_hull() -> void:
	var origin: Vector2 = Vector2(48.0, size.y - 64.0)
	var bar: Vector2 = Vector2(260.0, 12.0)
	var shield: ShieldState = _turret.shield
	var shield_origin: Vector2 = origin + Vector2(0.0, -44.0)
	_draw_panel(Rect2(shield_origin + Vector2(-14.0, -30.0), Vector2(bar.x + 28.0, 98.0)))
	var shield_color: Color = COLOR_SHIELD.lerp(Color.WHITE, _shield_flash * 0.7) if shield.is_up() else COLOR_ALERT
	_text(shield_origin + Vector2(0.0, -8.0), "SHIELD", 14, shield_color, HORIZONTAL_ALIGNMENT_LEFT)
	_text(shield_origin + Vector2(bar.x, -8.0), "%d / %d" % [ceili(shield.charge), ceili(shield.capacity)], 14, shield_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_bar(Rect2(shield_origin, bar), shield.get_fraction(), shield_color)

	var fraction: float = _turret.hull / _turret.max_hull if _turret.max_hull > 0.0 else 0.0
	var hull_color: Color = COLOR_MAIN
	if fraction <= LOW_HULL_FRACTION:
		# A low hull pulses red.
		hull_color = COLOR_ALERT.lerp(Color.WHITE, 0.35 + 0.35 * sin(_time_s * 9.0))
	_text(origin + Vector2(0.0, -8.0), "HULL", 14, hull_color, HORIZONTAL_ALIGNMENT_LEFT)
	_text(origin + Vector2(bar.x, -8.0), "%d / %d" % [ceili(_turret.hull), ceili(_turret.max_hull)], 14, hull_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_bar(Rect2(origin, bar), fraction, hull_color)


## A dark backing plate with a thin bright edge on the left.
func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, COLOR_PANEL)
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), COLOR_DIM)


## A framed bar with segment ticks.
func _draw_bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color(COLOR_DIM, 0.2))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), color)
	for segment: int in range(1, BAR_SEGMENTS):
		var x: float = rect.position.x + rect.size.x * float(segment) / float(BAR_SEGMENTS)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), COLOR_SHADOW, 1.5)
	draw_rect(rect.grow(2.0), COLOR_DIM, false, 1.0)


func _draw_messages(centre: Vector2) -> void:
	if _message_left_s > 0.0:
		var color: Color = COLOR_WARN
		color.a = clampf(_message_left_s, 0.0, 1.0)
		_text(Vector2(centre.x, size.y * 0.25), _message, 20, color, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_debug() -> void:
	var aim: TurretAim = _turret.aim
	var lines: PackedStringArray = [
		"%d fps" % Engine.get_frames_per_second(),
		"aim  yaw %+.1f°  pitch %+.1f°" % [aim.yaw_deg, aim.pitch_deg],
		"data: " + GameData.last_report.summary(),
		_power_debug_line(),
		_weapon_debug_line(),
		"preset: %s   F1 hide   F3 next preset   F4 debug menu   F5 reload data" % Graphics.preset_id,
	]
	for index: int in lines.size():
		_text(Vector2(48.0, 96.0 + index * 18.0), lines[index], 13, COLOR_DIM.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT)


## Held Tab: this stage so far, and what is in the air with its strengths.
func _draw_intel(centre: Vector2) -> void:
	var stats: StageStats = _stages.stats
	var counts: Dictionary = {}
	for enemy: Enemy in _enemies.get_enemies():
		counts[enemy.enemy_id] = int(counts.get(enemy.enemy_id, 0)) + 1
	var ids: Array = counts.keys()
	ids.sort()
	var panel: Rect2 = Rect2(centre + Vector2(-430.0, -300.0), Vector2(860.0, 250.0 + ids.size() * 26.0))
	draw_rect(panel, Color(COLOR_PANEL, 0.85))
	draw_rect(panel, COLOR_DIM, false, 1.0)
	var left: float = panel.position.x + 30.0
	var y: float = panel.position.y + 44.0
	_text(Vector2(left, y), "STAGE %d  %s" % [_stages.stage_number, str(_stages.stage_data.get("display_name", "")).to_upper()], 22, COLOR_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(panel.end.x - 30.0, y), str(GameState.get_difficulty().get("display_name", "")).to_upper(), 14, COLOR_DIM.lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	var facts: Array[Array] = [
		["TIME", "%d:%02d" % [int(stats.time_s) / 60, int(stats.time_s) % 60]],
		["KILLS", "%d" % stats.kills],
		["ACCURACY", "%d %%" % roundi(stats.accuracy_percent())],
		["INTERCEPTS", "%d" % stats.intercepts],
		["BOUNTY", "%d cr" % stats.bounty],
		["SHIELD BROKEN", "yes" if stats.shield_broken else "no"],
	]
	y += 40.0
	for index: int in facts.size():
		var x: float = left + 134.0 * index
		_text(Vector2(x, y), facts[index][0], 11, COLOR_DIM.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(x, y + 22.0), facts[index][1], 18, COLOR_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	y += 70.0
	var columns: Array[Array] = [["IN THE AIR", 0.0], ["COUNT", 250.0], ["HULL", 340.0], ["ARMOUR", 440.0], ["SHIELD", 540.0], ["BOUNTY", 640.0]]
	for column: Array in columns:
		_text(Vector2(left + float(column[1]), y), column[0], 11, COLOR_DIM.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
	if ids.is_empty():
		_text(Vector2(left, y + 28.0), "Nothing yet.", 15, COLOR_DIM.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT)
	for id: String in ids:
		y += 26.0
		var data: Dictionary = GameData.loader.get_entry("enemies", id)
		var cells: Array = [str(data.get("display_name", id)), "%d" % counts[id], "%d" % data.get("hp", 0), "%d" % data.get("armour", 0), "%d" % data.get("shield", 0), "%d cr" % data.get("credit_bounty", 0)]
		for index: int in cells.size():
			_text(Vector2(left + float(columns[index][1]), y), cells[index], 15, COLOR_MAIN, HORIZONTAL_ALIGNMENT_LEFT)


## Draws text anchored at its baseline; alignment is relative to `at`.
func _text(at: Vector2, text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> void:
	var text_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = at
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= text_width * 0.5
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= text_width
	draw_string(_font, origin + Vector2(1.0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(COLOR_SHADOW, COLOR_SHADOW.a * color.a))
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _on_target_hit(_slot: StringName, killed: bool) -> void:
	if killed:
		_kill_left_s = KILL_MARKER_S
	else:
		_hit_left_s = HIT_MARKER_S


func _on_ui_message(text: String) -> void:
	_message = text
	_message_left_s = MESSAGE_S


## Red frame that flashes when the turret is hit.
func _draw_damage_flash() -> void:
	if _damage_flash <= 0.0:
		return
	var color: Color = COLOR_ALERT
	color.a = 0.45 * _damage_flash
	var thickness: float = 26.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, thickness)), color)
	draw_rect(Rect2(Vector2(0.0, size.y - thickness), Vector2(size.x, thickness)), color)
	draw_rect(Rect2(Vector2(0.0, thickness), Vector2(thickness, size.y - thickness * 2.0)), color)
	draw_rect(Rect2(Vector2(size.x - thickness, thickness), Vector2(thickness, size.y - thickness * 2.0)), color)


func _draw_stage_info(centre: Vector2) -> void:
	if _stages.state == StageManager.State.IDLE:
		return
	var fields: Array[Array] = [
		["STAGE", "%d" % _stages.stage_number],
		["WAVE", "%d / %d" % [mini(_stages.wave_index + 1, _stages.get_wave_count()), _stages.get_wave_count()]],
		["HOSTILES", "%d" % (_enemies.get_enemy_count() if _enemies != null else 0)],
		["BOUNTY", "%d cr" % _stages.stats.bounty],
	]
	var cell: float = 150.0
	var left: float = centre.x - cell * fields.size() * 0.5
	_draw_panel(Rect2(Vector2(left - 10.0, 18.0), Vector2(cell * fields.size() + 20.0, 50.0)))
	for index: int in fields.size():
		var x: float = left + cell * (index + 0.5)
		_text(Vector2(x, 36.0), fields[index][0], 11, COLOR_DIM.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(x, 58.0), fields[index][1], 18, COLOR_MAIN, HORIZONTAL_ALIGNMENT_CENTER)


## Marks every threat: a small diamond on distant ones that are on screen, an
## arrow at the screen edge for those outside the view.
func _draw_threats(centre: Vector2) -> void:
	var camera: Camera3D = _turret.rig.get_camera()
	if camera == null:
		return
	var view: Transform3D = camera.global_transform.affine_inverse()
	var screen: Rect2 = Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)
	var arrows: int = 0
	# Upgrades switch HUD features on (Targeting Computer, Threat Radar).
	var flags: Dictionary = GameState.get_hud_flags()
	_show_health_bars = flags.get("enemy_health_bars", false)
	var warn_projectiles: bool = flags.get("projectile_warnings", false)
	var lead_speed: float = _lead_speed() if flags.get("lead_indicators", false) else 0.0
	for enemy: Enemy in _enemies.get_enemies():
		if enemy.is_alive():
			arrows += _draw_threat(camera, view, screen, centre, enemy, COLOR_WARN, arrows)
			for weak_point: WeakPoint in enemy.get_weak_points():
				_draw_weak_point(camera, screen, weak_point)
			if lead_speed > 0.0:
				_draw_lead(camera, screen, enemy, lead_speed)
	var incoming: bool = false
	for projectile: EnemyProjectile in _enemies.get_projectiles():
		if projectile.is_alive():
			incoming = true
			# Without the Threat Radar, ordnance outside the view gets no arrow.
			arrows += _draw_threat(camera, view, screen, centre, projectile, COLOR_ALERT, arrows if warn_projectiles else MAX_EDGE_INDICATORS)
	if incoming and warn_projectiles:
		var warning: Color = COLOR_ALERT
		warning.a = 0.6 + 0.4 * sin(_time_s * 10.0)
		_text(Vector2(centre.x, 74.0), "INCOMING ORDNANCE", 16, warning, HORIZONTAL_ALIGNMENT_CENTER)


## Draws one threat marker. Returns 1 if it used an edge arrow, else 0.
func _draw_threat(camera: Camera3D, view: Transform3D, screen: Rect2, centre: Vector2, target: CombatTarget, color: Color, arrows_used: int) -> int:
	var world: Vector3 = target.global_position
	var local: Vector3 = view * world
	if local.z < 0.0:
		var point: Vector2 = camera.unproject_position(world)
		if screen.has_point(point):
			# The diamond is as large as the area that counts as a hit.
			var focal: float = (size.y * 0.5) / tan(deg_to_rad(camera.fov) * 0.5)
			var reach: float = clampf(target.get_hit_radius() / maxf(-local.z, 1.0) * focal, 7.0, 400.0)
			for corner: int in 4:
				var from: Vector2 = point + Vector2.UP.rotated(corner * PI * 0.5) * reach
				var to: Vector2 = point + Vector2.UP.rotated((corner + 1) * PI * 0.5) * reach
				draw_line(from, to, color, 1.5, true)
			if _show_health_bars and target.stats.hp < target.stats.max_hp:
				var bar: Rect2 = Rect2(point + Vector2(-18.0, reach + 5.0), Vector2(36.0, 4.0))
				draw_rect(bar, COLOR_DIM)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(target.stats.hp / target.stats.max_hp, 0.0, 1.0), bar.size.y)), color)
			return 0
	if arrows_used >= MAX_EDGE_INDICATORS:
		return 0
	# Off screen: an arrow on an ellipse inside the screen, pointing at the threat.
	var direction: Vector2 = Vector2(local.x, -local.y)
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var radii: Vector2 = size * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var tip: Vector2 = centre + Vector2(direction.x * radii.x, direction.y * radii.y)
	var side: Vector2 = direction.orthogonal() * 9.0
	var base: Vector2 = tip - direction * 20.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), color)
	return 1

## The always-visible power split: weapons on top, shields below. The divider
## slides on every wheel step and the gauge brightens briefly.
func _draw_power_gauge(centre: Vector2) -> void:
	var height: float = 120.0
	var width: float = 16.0
	var top_left: Vector2 = Vector2(centre.x - 250.0, size.y - 40.0 - height)
	var weapon_height: float = height * (1.0 - _shown_share)
	var glow: float = 0.75 + 0.25 * _power_pulse
	draw_rect(Rect2(top_left, Vector2(width, weapon_height)), Color(COLOR_WEAPON, glow))
	draw_rect(Rect2(top_left + Vector2(0.0, weapon_height), Vector2(width, height - weapon_height)), Color(COLOR_SHIELD, glow))
	draw_rect(Rect2(top_left, Vector2(width, height)), COLOR_MAIN, false, 1.0 + 2.0 * _power_pulse)
	# Step marks and the default position.
	var power: PowerSystem = _turret.power
	var steps: int = roundi((power.max_share - power.min_share) / maxf(power.step, 0.01))
	for index: int in range(1, steps):
		var y: float = top_left.y + height * index / steps
		draw_line(Vector2(top_left.x + width, y), Vector2(top_left.x + width + 4.0, y), COLOR_DIM, 1.0)
	var divider_y: float = top_left.y + weapon_height
	draw_line(Vector2(top_left.x - 6.0, divider_y), Vector2(top_left.x + width + 8.0, divider_y), Color.WHITE, 2.0)
	_text(top_left + Vector2(-10.0, 12.0), "WPN %d%%" % roundi(power.get_weapon_share() * 100.0), 13, COLOR_WEAPON, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(top_left + Vector2(-10.0, height), "SHD %d%%" % roundi(power.shield_share * 100.0), 13, COLOR_SHIELD, HORIZONTAL_ALIGNMENT_RIGHT)


## Debug overlay: what the power split does to the shield right now.
func _power_debug_line() -> String:
	var power: PowerSystem = _turret.power
	var shield: ShieldState = _turret.shield
	var multiplier: float = maxf(power.shield_recharge_multiplier(), shield.min_recharge_multiplier)
	return "power: shield share %.1f   recharge x%.2f = %.1f/s   weapon output x%.2f" % [
		power.shield_share, multiplier, shield.recharge_per_s * multiplier, power.weapon_output_multiplier()]


## Debug overlay: what the power split does to the primary weapon right now.
func _weapon_debug_line() -> String:
	var weapon: Weapon = _turret.get_weapon(Turret.SLOT_PRIMARY)
	if weapon == null:
		return "primary: none"
	var damage: float = float(weapon.data.get("damage", 0.0)) * weapon.get_damage_scale()
	var rate: float = float(weapon.data.get("fire_rate", 0.0)) * weapon.get_rate_scale()
	return "primary: %.1f dmg x %.1f /s = %.0f dps   cooling x%.2f" % [damage, rate, damage * rate, weapon.get_rate_scale()]

## Charge ring around the crosshair: railgun charge, beam ramp, barrel spin.
func _draw_charge(centre: Vector2, weapon: Weapon, radius: float) -> void:
	var charge: float = weapon.get_charge_fraction()
	if charge <= 0.01:
		return
	var color: Color = COLOR_WEAPON if charge < 1.0 else Color.WHITE
	draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, color, 2.5, true)


## A white diamond on each weak point of a large enemy.
func _draw_weak_point(camera: Camera3D, screen: Rect2, weak_point: WeakPoint) -> void:
	if not is_instance_valid(weak_point) or not weak_point.is_alive() or camera.is_position_behind(weak_point.global_position):
		return
	var point: Vector2 = camera.unproject_position(weak_point.global_position)
	if not screen.has_point(point):
		return
	for corner: int in 4:
		draw_line(point + Vector2.UP.rotated(corner * PI * 0.5) * 9.0, point + Vector2.UP.rotated((corner + 1) * PI * 0.5) * 9.0, Color(1, 1, 1, 0.9), 2.0, true)
	draw_circle(point, 2.0, Color(1, 1, 1, 0.9))


## Muzzle speed of the primary weapon if it fires projectiles with travel
## time, else 0 (instant-hit weapons need no lead).
func _lead_speed() -> float:
	var weapon: Weapon = _turret.get_weapon(Turret.SLOT_PRIMARY)
	if weapon == null or not weapon.data.has("projectile"):
		return 0.0
	return (weapon.data["projectile"] as Dictionary).get("speed_mps", 0.0)


## Targeting Computer: a small circle where to aim so a projectile meets the
## enemy, joined to the enemy by a thin line.
func _draw_lead(camera: Camera3D, screen: Rect2, enemy: Enemy, projectile_speed: float) -> void:
	if enemy.velocity.length_squared() < 4.0:
		return
	var origin: Vector3 = camera.global_position
	var lead_point: Vector3 = enemy.global_position
	# Two refinement steps are plenty at these speeds.
	for step: int in 2:
		lead_point = enemy.global_position + enemy.velocity * (origin.distance_to(lead_point) / projectile_speed)
	if camera.is_position_behind(lead_point) or camera.is_position_behind(enemy.global_position):
		return
	var lead: Vector2 = camera.unproject_position(lead_point)
	var at: Vector2 = camera.unproject_position(enemy.global_position)
	if not screen.has_point(lead) or lead.distance_to(at) < 6.0:
		return
	draw_line(at, lead, Color(COLOR_MAIN, 0.4), 1.0, true)
	draw_arc(lead, 6.0, 0.0, TAU, 16, COLOR_MAIN, 1.5, true)