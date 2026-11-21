extends GutTest
## Tests for TurretAim: arc limits, soft zone, smoothing and angle maths.

var _aim: TurretAim


func before_each() -> void:
	_aim = TurretAim.new()
	_aim.configure({
		"yaw_min_deg": -80.0, "yaw_max_deg": 80.0,
		"pitch_min_deg": -5.0, "pitch_max_deg": 85.0,
		"edge_soft_zone_deg": 4.0, "edge_min_input_scale": 0.5,
	})


func test_input_moves_aim_one_to_one_away_from_limits() -> void:
	_aim.apply_input(10.0, 5.0)
	assert_almost_eq(_aim.yaw_deg, 10.0, 0.0001)
	assert_almost_eq(_aim.pitch_deg, 5.0, 0.0001)


func test_aim_is_clamped_to_the_arc() -> void:
	for step: int in 200:
		_aim.apply_input(5.0, 5.0)
	assert_almost_eq(_aim.yaw_deg, 80.0, 0.0001)
	assert_almost_eq(_aim.pitch_deg, 85.0, 0.0001)
	for step: int in 400:
		_aim.apply_input(-5.0, -5.0)
	assert_almost_eq(_aim.yaw_deg, -80.0, 0.0001)
	assert_almost_eq(_aim.pitch_deg, -5.0, 0.0001)


func test_soft_zone_slows_movement_towards_the_limit_only() -> void:
	_aim.yaw_deg = 78.0
	_aim.apply_input(1.0, 0.0)
	assert_lt(_aim.yaw_deg, 79.0, "moving into the limit is slowed")
	assert_gt(_aim.yaw_deg, 78.0)
	_aim.yaw_deg = 78.0
	_aim.apply_input(-1.0, 0.0)
	assert_almost_eq(_aim.yaw_deg, 77.0, 0.0001, "moving away is not slowed")


func test_edge_factor_reports_proximity() -> void:
	assert_eq(_aim.yaw_edge_factor(), 0.0)
	_aim.yaw_deg = 80.0
	assert_almost_eq(_aim.yaw_edge_factor(), 1.0, 0.0001)
	_aim.yaw_deg = -78.0
	assert_almost_eq(_aim.yaw_edge_factor(), -0.5, 0.0001)
	_aim.pitch_deg = 85.0
	assert_almost_eq(_aim.pitch_edge_factor(), 1.0, 0.0001)


func test_zero_smoothing_snaps_the_visual() -> void:
	_aim.apply_input(30.0, 10.0)
	_aim.update_visual(0.016, 0.0)
	assert_eq(_aim.visual_yaw_deg, _aim.yaw_deg)
	assert_eq(_aim.visual_pitch_deg, _aim.pitch_deg)


func test_smoothing_converges_without_delaying_the_aim() -> void:
	_aim.apply_input(30.0, 0.0)
	assert_almost_eq(_aim.yaw_deg, 30.0, 0.0001, "the aim itself is immediate")
	_aim.update_visual(0.016, 0.03)
	assert_gt(_aim.visual_yaw_deg, 0.0)
	assert_lt(_aim.visual_yaw_deg, 30.0)
	for step: int in 60:
		_aim.update_visual(0.016, 0.03)
	assert_almost_eq(_aim.visual_yaw_deg, 30.0, 0.01)


func test_direction_and_angles_round_trip() -> void:
	assert_almost_eq(TurretAim.direction_from(0.0, 0.0), Vector3(0, 0, -1), Vector3.ONE * 0.0001)
	assert_almost_eq(TurretAim.direction_from(90.0, 0.0), Vector3(1, 0, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(TurretAim.direction_from(0.0, 90.0), Vector3(0, 1, 0), Vector3.ONE * 0.0001)
	var angles: Vector2 = TurretAim.angles_to(TurretAim.direction_from(-37.0, 22.0))
	assert_almost_eq(angles.x, -37.0, 0.001)
	assert_almost_eq(angles.y, 22.0, 0.001)
