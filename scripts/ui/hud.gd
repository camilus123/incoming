extends Control
## In-game HUD (M1 version): crosshair, weapon heat, missile status, lock
## brackets, hit markers, aim-arc indicators and the hull bar.
##
## Everything is drawn in `_draw()` in UI units. The project's stretch
## settings scale it with the resolution and keep it centred on any aspect
## ratio, so nothing here depends on the window size.

const COLOR_MAIN: Color = Color(0.6, 0.95, 1.0, 0.9)
const COLOR_DIM: Color = Color(0.6, 0.95, 1.0, 0.35)
const COLOR_WARN: Color = Color(1.0, 0.7, 0.2, 0.95)
const COLOR_ALERT: Color = Color(1.0, 0.25, 0.2, 0.95)
const COLOR_LOCK: Color = Color(1.0, 0.3, 0.25, 0.95)
const HEAT_RADIUS: float = 52.0
const HIT_MARKER_S: float = 0.14
const KILL_MARKER_S: float = 0.35
const MESSAGE_S: float = 2.5

var _turret: Turret
var _font: Font
var _hit_left_s: float = 0.0
var _kill_left_s: float = 0.0
var _message: String = ""
var _message_left_s: float = 0.0
var _time_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	EventBus.target_hit.connect(_on_target_hit)
	EventBus.ui_message.connect(_on_ui_message)


func _process(delta_s: float) -> void:
	if _turret == null:
		_turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	_time_s += delta_s
	_hit_left_s = maxf(0.0, _hit_left_s - delta_s)
	_kill_left_s = maxf(0.0, _kill_left_s - delta_s)
	_message_left_s = maxf(0.0, _message_left_s - delta_s)
	queue_redraw()


func _draw() -> void:
	if _turret == null:
		return
	var centre: Vector2 = size * 0.5
	var primary: Weapon = _turret.get_weapon(Turret.SLOT_PRIMARY)
	var alternate: Weapon = _turret.get_weapon(Turret.SLOT_ALTERNATE)

	_draw_crosshair(centre, primary)
	if primary != null:
		_draw_heat_arc(centre, primary, -1.0)
	if alternate != null:
		_draw_heat_arc(centre, alternate, 1.0)
		_draw_alternate_status(centre, alternate)
		_draw_locks(alternate)
	_draw_hit_markers(centre)
	_draw_arc_indicator(centre)
	_draw_edge_warnings(centre)
	_draw_hull()
	_draw_messages(centre)
	if OS.is_debug_build():
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
	if reload > 0.0:
		var bar: Rect2 = Rect2(anchor + Vector2(0.0, 8.0), Vector2(54.0, 4.0))
		draw_rect(bar, COLOR_DIM)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - reload), bar.size.y)), COLOR_WARN)
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
	var fraction: float = _turret.hull / _turret.max_hull if _turret.max_hull > 0.0 else 0.0
	_text(origin + Vector2(0.0, -8.0), "HULL  %d / %d" % [ceili(_turret.hull), ceili(_turret.max_hull)], 14, COLOR_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	draw_rect(Rect2(origin, bar), COLOR_DIM)
	draw_rect(Rect2(origin, Vector2(bar.x * fraction, bar.y)), COLOR_MAIN if fraction > 0.3 else COLOR_ALERT)


func _draw_messages(centre: Vector2) -> void:
	if get_tree().paused:
		_text(Vector2(centre.x, centre.y - 140.0), "PAUSED", 34, COLOR_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(centre.x, centre.y - 108.0), "Esc to resume", 16, COLOR_DIM.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
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
		"F5 reload data   Esc pause",
	]
	for index: int in lines.size():
		_text(Vector2(48.0, 48.0 + index * 18.0), lines[index], 13, COLOR_DIM.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT)


## Draws text anchored at its baseline; alignment is relative to `at`.
func _text(at: Vector2, text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> void:
	var text_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = at
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= text_width * 0.5
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= text_width
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _on_target_hit(_slot: StringName, killed: bool) -> void:
	if killed:
		_kill_left_s = KILL_MARKER_S
	else:
		_hit_left_s = HIT_MARKER_S


func _on_ui_message(text: String) -> void:
	_message = text
	_message_left_s = MESSAGE_S
