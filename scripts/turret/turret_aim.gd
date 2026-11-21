class_name TurretAim
extends RefCounted
## Aim state of the turret: where the player is aiming and where the visible
## mechanics currently point.
##
## `yaw_deg` / `pitch_deg` follow the mouse immediately (shots and the camera
## use these, so aiming never lags). `visual_yaw_deg` / `visual_pitch_deg`
## chase them with a small smoothing to give the turret model some weight.
## Yaw: 0 = straight ahead, positive = right. Pitch: 0 = horizon, positive = up.

var yaw_min_deg: float = -80.0
var yaw_max_deg: float = 80.0
var pitch_min_deg: float = -5.0
var pitch_max_deg: float = 85.0
## Width of the zone before each limit where input is progressively reduced.
var soft_zone_deg: float = 4.0
## Input scale right at the limit (1 = no resistance).
var soft_zone_min_scale: float = 0.35

var yaw_deg: float = 0.0
var pitch_deg: float = 0.0
var visual_yaw_deg: float = 0.0
var visual_pitch_deg: float = 0.0


## Reads the limits from the "aim" block of turret.json.
func configure(aim_config: Dictionary) -> void:
	yaw_min_deg = aim_config.get("yaw_min_deg", yaw_min_deg)
	yaw_max_deg = aim_config.get("yaw_max_deg", yaw_max_deg)
	pitch_min_deg = aim_config.get("pitch_min_deg", pitch_min_deg)
	pitch_max_deg = aim_config.get("pitch_max_deg", pitch_max_deg)
	soft_zone_deg = aim_config.get("edge_soft_zone_deg", soft_zone_deg)
	soft_zone_min_scale = aim_config.get("edge_min_input_scale", soft_zone_min_scale)
	yaw_deg = clampf(yaw_deg, yaw_min_deg, yaw_max_deg)
	pitch_deg = clampf(pitch_deg, pitch_min_deg, pitch_max_deg)


## Moves the aim by the given angles. Movement towards a limit is slowed down
## inside the soft zone and stops at the limit.
func apply_input(delta_yaw_deg: float, delta_pitch_deg: float) -> void:
	yaw_deg = _move_axis(yaw_deg, delta_yaw_deg, yaw_min_deg, yaw_max_deg)
	pitch_deg = _move_axis(pitch_deg, delta_pitch_deg, pitch_min_deg, pitch_max_deg)


## Advances the visible mechanics towards the aim. `smoothing_s` is the time
## constant in seconds; 0 snaps them to the aim immediately.
func update_visual(delta_s: float, smoothing_s: float) -> void:
	if smoothing_s <= 0.0:
		visual_yaw_deg = yaw_deg
		visual_pitch_deg = pitch_deg
		return
	var blend: float = 1.0 - exp(-delta_s / smoothing_s)
	visual_yaw_deg = lerpf(visual_yaw_deg, yaw_deg, blend)
	visual_pitch_deg = lerpf(visual_pitch_deg, pitch_deg, blend)


## How deep the yaw is inside a soft zone: -1 at the left limit, +1 at the
## right limit, 0 outside the soft zones. Used by the HUD edge markers.
func yaw_edge_factor() -> float:
	return _edge_factor(yaw_deg, yaw_min_deg, yaw_max_deg)


## Same for pitch: -1 at the lower limit, +1 at the upper limit.
func pitch_edge_factor() -> float:
	return _edge_factor(pitch_deg, pitch_min_deg, pitch_max_deg)


## Unit vector for an aim, in the turret's local space (-Z is straight ahead).
static func direction_from(aim_yaw_deg: float, aim_pitch_deg: float) -> Vector3:
	var yaw: float = deg_to_rad(aim_yaw_deg)
	var pitch: float = deg_to_rad(aim_pitch_deg)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


## Inverse of `direction_from`: returns Vector2(yaw_deg, pitch_deg).
static func angles_to(direction: Vector3) -> Vector2:
	var unit: Vector3 = direction.normalized()
	return Vector2(rad_to_deg(atan2(unit.x, -unit.z)), rad_to_deg(asin(clampf(unit.y, -1.0, 1.0))))


func _move_axis(value: float, delta: float, low: float, high: float) -> float:
	if delta == 0.0:
		return value
	var distance_to_limit: float = (high - value) if delta > 0.0 else (value - low)
	var scale: float = 1.0
	if soft_zone_deg > 0.0 and distance_to_limit < soft_zone_deg:
		scale = lerpf(soft_zone_min_scale, 1.0, clampf(distance_to_limit / soft_zone_deg, 0.0, 1.0))
	return clampf(value + delta * scale, low, high)


func _edge_factor(value: float, low: float, high: float) -> float:
	if soft_zone_deg <= 0.0:
		return 0.0
	if high - value < soft_zone_deg:
		return clampf(1.0 - (high - value) / soft_zone_deg, 0.0, 1.0)
	if value - low < soft_zone_deg:
		return -clampf(1.0 - (value - low) / soft_zone_deg, 0.0, 1.0)
	return 0.0
