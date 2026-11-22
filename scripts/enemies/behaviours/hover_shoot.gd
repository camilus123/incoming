extends EnemyBehaviour
## Module "hover_shoot": fly to a standoff position, hover there facing the
## turret, sidestep now and then, and fire every listed attack when ready.
## Parameters:
##   hover_distance_m [min, max]     standoff range from the turret
##   sidestep_distance_m             how far each sidestep goes (0 = none)
##   sidestep_interval_s [min, max]  time between sidesteps
##   attacks                         ids of the attacks to use (empty = all)
##   rotate_deg_s                    once in position, turn slowly on the spot (capital ships)

const ARRIVE_M: float = 40.0

var _anchor: Vector3
var _hover_point: Vector3
var _sidestep_left_s: float = 0.0
var _arrived: bool = false


func _on_setup() -> void:
	# Keep the bearing and elevation of the spawn point, at the hover range.
	var turret_point: Vector3 = enemy.get_turret_point()
	var from_turret: Vector3 = enemy.global_position - turret_point
	var distance: float = minf(from_turret.length(), _param_in_range("hover_distance_m", 900.0, 1300.0))
	_anchor = turret_point + from_turret.normalized() * distance
	_hover_point = _anchor
	_arrived = false
	_sidestep_left_s = _param_in_range("sidestep_interval_s", 4.0, 7.0)
	enemy.face_turret = true


func tick(delta_s: float) -> void:
	var to_point: Vector3 = _hover_point - enemy.global_position
	var distance: float = to_point.length()
	if distance > ARRIVE_M:
		enemy.velocity = to_point / distance * enemy.speed_mps
	else:
		if not _arrived and _param("rotate_deg_s", 0.0) != 0.0:
			# Start the slow turn from the current heading.
			enemy._rotation_rad = enemy.global_transform.basis.get_euler().y
			enemy.rotate_deg_s = _param("rotate_deg_s", 0.0)
		_arrived = true
		# Ease to a stop on the hover point.
		enemy.velocity = to_point * 0.5

	if _arrived and _param("sidestep_distance_m", 0.0) > 0.0:
		_sidestep_left_s -= delta_s
		if _sidestep_left_s <= 0.0:
			_sidestep_left_s = _param_in_range("sidestep_interval_s", 4.0, 7.0)
			var outward: Vector3 = (_anchor - enemy.get_turret_point()).normalized()
			var side: Vector3 = outward.cross(Vector3.UP).normalized()
			_hover_point = _anchor + side * randf_range(-1.0, 1.0) * _param("sidestep_distance_m", 0.0) + Vector3.UP * randf_range(-0.3, 0.3) * _param("sidestep_distance_m", 0.0)

	var range_to_turret: float = enemy.global_position.distance_to(enemy.get_turret_point())
	var listed: Array = params.get("attacks", [])
	for attack: Dictionary in enemy.data.get("attacks", []):
		if not listed.is_empty() and not listed.has(attack["id"]):
			continue
		if attack["type"] != "collision" and range_to_turret <= float(attack.get("range_m", 0.0)):
			enemy.try_attack_id(attack["id"])
