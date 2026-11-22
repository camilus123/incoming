extends GutTest
## Graphics pass (M6): presets, the data-driven environment and the pooled
## glow batches.


func after_each() -> void:
	Graphics.set_preset("")


func test_every_preset_can_be_applied() -> void:
	var ids: Array[String] = Graphics.get_preset_ids()
	assert_gt(ids.size(), 3, "low, medium, high and ultra exist")
	for id: String in ids:
		Graphics.set_preset(id)
		assert_eq(Graphics.preset_id, id)
		assert_between(get_tree().root.scaling_3d_scale, 0.25, 2.0, "%s: render scale is applied" % id)


func test_unknown_preset_falls_back_to_the_default() -> void:
	Graphics.set_preset("no_such_preset")
	assert_eq(Graphics.preset_id, GameData.loader.get_config("graphics_presets")["default"])


func test_cycling_visits_every_preset() -> void:
	var seen: Dictionary = {}
	for step: int in Graphics.get_preset_ids().size():
		Graphics.cycle_preset()
		seen[Graphics.preset_id] = true
	assert_eq(seen.size(), Graphics.get_preset_ids().size())


func test_fsr2_replaces_taa() -> void:
	for id: String in Graphics.get_preset_ids():
		Graphics.set_preset(id)
		if Graphics.get_value("upscaler", "none") == "fsr2":
			assert_false(get_tree().root.use_taa, "%s: FSR 2 has its own anti-aliasing" % id)


func test_every_stage_uses_a_time_of_day_that_exists() -> void:
	var times: Dictionary = GameData.loader.get_config("environments")["times"]
	var stages: Dictionary = GameData.loader.get_category("stages")
	assert_gt(stages.size(), 0)
	for stage_id: String in stages:
		assert_true(times.has(stages[stage_id]["time_of_day"]), "%s: time of day '%s'" % [stage_id, stages[stage_id]["time_of_day"]])


func test_environment_switches_time_and_survives_an_unknown_one() -> void:
	var environment: FrontierEnvironment = (load("res://scenes/environment/frontier_basic.tscn") as PackedScene).instantiate()
	add_child_autofree(environment)
	environment.apply_time("night")
	assert_eq(environment.get_time_id(), "night")
	var night_energy: float = (environment.get_node("Sun") as DirectionalLight3D).light_energy
	environment.apply_time("day")
	assert_gt((environment.get_node("Sun") as DirectionalLight3D).light_energy, night_energy, "the day sun is brighter than moonlight")
	environment.apply_time("no_such_time")
	assert_eq(environment.get_time_id(), GameData.loader.get_config("environments")["default_time"])


func test_ground_is_flat_at_the_turret_and_mountains_stand_far_away() -> void:
	var environment: FrontierEnvironment = (load("res://scenes/environment/frontier_basic.tscn") as PackedScene).instantiate()
	add_child_autofree(environment)
	for point: Vector2 in [Vector2(0, 0), Vector2(120, -80), Vector2(-250, 100)]:
		assert_lt(environment.get_height(point.x, point.y), 1.0, "flat within 300 m of the turret")
	var highest: float = 0.0
	for step: int in 72:
		var angle: float = TAU * step / 72.0
		highest = maxf(highest, environment.get_height(cos(angle) * 10000.0, sin(angle) * 10000.0))
	assert_gt(highest, 200.0, "mountains on the horizon")
	# Enemies spawn from 1200 m out at 8 degrees or more; the ground must stay well below them.
	for step: int in 72:
		var angle: float = TAU * step / 72.0
		assert_lt(environment.get_height(cos(angle) * 3000.0, sin(angle) * 3000.0), 40.0)


func test_environment_follows_the_graphics_preset() -> void:
	var environment: FrontierEnvironment = (load("res://scenes/environment/frontier_basic.tscn") as PackedScene).instantiate()
	add_child_autofree(environment)
	for id: String in Graphics.get_preset_ids():
		Graphics.set_preset(id)
		var settings: Environment = environment.get_environment()
		assert_eq(settings.ssao_enabled, bool(Graphics.get_value("ssao", true)), "%s: SSAO" % id)
		assert_eq(settings.ssr_enabled, bool(Graphics.get_value("ssr", false)), "%s: SSR" % id)
		assert_eq(settings.volumetric_fog_enabled, bool(Graphics.get_value("volumetric_fog", false)), "%s: volumetric fog" % id)
		assert_eq(settings.sdfgi_enabled, Graphics.get_value("gi", "off") == "sdfgi", "%s: SDFGI" % id)


func test_glow_batch_reuses_slots_round_robin() -> void:
	var box: BoxMesh = BoxMesh.new()
	var batch: GlowBatch = GlowBatch.create(box, 3, "TestBatch")
	add_child_autofree(batch)
	assert_eq([batch.take_slot(), batch.take_slot(), batch.take_slot(), batch.take_slot()], [0, 1, 2, 0])
	assert_eq(batch.multimesh.instance_count, 3)
	# Instance transforms cannot be read back without a real renderer (the
	# tests run headless), so showing and hiding is only checked not to fail.
	batch.show_steady(1, Transform3D(Basis.IDENTITY, Vector3(5, 6, 7)), Color.RED, 2.0)
	batch.show_timed(2, Transform3D.IDENTITY, Color.RED, 2.0, 0.5, 0.2)
	batch.hide_slot(1)
