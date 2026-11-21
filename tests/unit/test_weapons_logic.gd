extends GutTest
## Tests for HeatModel, DamageCalc, TargetStats and the archetype list.

const RULES: Dictionary = {
	"shield_damage_multipliers": {"energy": 2.0, "kinetic": 0.5, "explosive": 1.0},
	"armour_min_damage_fraction": 0.1,
	"splash_edge_damage_fraction": 0.4,
}


func _heat() -> HeatModel:
	var heat: HeatModel = HeatModel.new()
	heat.configure({"per_shot": 0.25, "cooling_per_s": 0.5, "cooling_delay_s": 0.2, "overheat_unlock": 0.4})
	return heat


func _stats(data: Dictionary) -> TargetStats:
	return TargetStats.from_data(data)


func test_heat_builds_per_shot_and_overheats_at_one() -> void:
	var heat: HeatModel = _heat()
	assert_false(heat.add_shot())
	assert_almost_eq(heat.heat, 0.25, 0.0001)
	heat.add_shot()
	heat.add_shot()
	assert_true(heat.add_shot(), "the fourth shot overheats")
	assert_false(heat.can_fire())


func test_heat_cools_only_after_the_delay() -> void:
	var heat: HeatModel = _heat()
	heat.add_shot()
	heat.tick(0.1)
	assert_almost_eq(heat.heat, 0.25, 0.0001)
	heat.tick(0.2)
	assert_lt(heat.heat, 0.25)


func test_overheat_unlocks_at_the_threshold() -> void:
	var heat: HeatModel = _heat()
	for shot: int in 4:
		heat.add_shot()
	heat.tick(1.0)
	assert_false(heat.can_fire(), "still above the unlock threshold")
	heat.tick(0.3)
	assert_true(heat.can_fire())


func test_cooling_multiplier_scales_cooling() -> void:
	var slow: HeatModel = _heat()
	var fast: HeatModel = _heat()
	slow.add_shot()
	fast.add_shot()
	slow.tick(0.4, 0.5)
	fast.tick(0.4, 1.5)
	assert_gt(slow.heat, fast.heat)


func test_plain_hit_reduces_hp() -> void:
	var stats: TargetStats = _stats({"hp": 100.0})
	var result: DamageResult = DamageCalc.apply(30.0, "energy", 0.0, stats, RULES)
	assert_almost_eq(stats.hp, 70.0, 0.0001)
	assert_almost_eq(result.hull_damage, 30.0, 0.0001)
	assert_false(result.killed)


func test_kill_is_reported_and_hp_stops_at_zero() -> void:
	var stats: TargetStats = _stats({"hp": 20.0})
	var result: DamageResult = DamageCalc.apply(50.0, "kinetic", 0.0, stats, RULES)
	assert_true(result.killed)
	assert_eq(stats.hp, 0.0)
	assert_almost_eq(result.hull_damage, 20.0, 0.0001)


func test_armour_is_flat_reduction_countered_by_pierce() -> void:
	var stats: TargetStats = _stats({"hp": 100.0, "armour": 8.0})
	DamageCalc.apply(20.0, "kinetic", 0.0, stats, RULES)
	assert_almost_eq(stats.hp, 88.0, 0.0001)
	DamageCalc.apply(20.0, "kinetic", 6.0, stats, RULES)
	assert_almost_eq(stats.hp, 70.0, 0.0001, "pierce 6 leaves 2 armour")
	DamageCalc.apply(20.0, "kinetic", 50.0, stats, RULES)
	assert_almost_eq(stats.hp, 50.0, 0.0001, "pierce never adds damage")


func test_armour_never_removes_more_than_the_minimum_fraction() -> void:
	var stats: TargetStats = _stats({"hp": 100.0, "armour": 30.0})
	DamageCalc.apply(9.0, "energy", 0.0, stats, RULES)
	assert_almost_eq(stats.hp, 99.1, 0.0001)


func test_resistance_reduces_hull_damage() -> void:
	var stats: TargetStats = _stats({"hp": 100.0, "resistances": {"explosive": 0.25}})
	DamageCalc.apply(40.0, "explosive", 0.0, stats, RULES)
	assert_almost_eq(stats.hp, 70.0, 0.0001)


func test_shield_absorbs_with_type_multiplier() -> void:
	var energy: TargetStats = _stats({"hp": 100.0, "shield": 100.0})
	DamageCalc.apply(10.0, "energy", 0.0, energy, RULES)
	assert_almost_eq(energy.shield, 80.0, 0.0001, "energy does double damage to shields")
	assert_eq(energy.hp, 100.0)
	var kinetic: TargetStats = _stats({"hp": 100.0, "shield": 100.0})
	DamageCalc.apply(10.0, "kinetic", 0.0, kinetic, RULES)
	assert_almost_eq(kinetic.shield, 95.0, 0.0001, "kinetic does half damage to shields")


func test_shield_break_carries_the_rest_to_the_hull() -> void:
	var stats: TargetStats = _stats({"hp": 100.0, "shield": 10.0})
	# 20 energy = 40 against the shield; a quarter breaks it, three quarters go on.
	var result: DamageResult = DamageCalc.apply(20.0, "energy", 0.0, stats, RULES)
	assert_true(result.shield_broken)
	assert_eq(stats.shield, 0.0)
	assert_almost_eq(stats.hp, 85.0, 0.0001)


func test_shield_regenerates_after_the_delay() -> void:
	var stats: TargetStats = _stats({"hp": 100.0, "shield": 50.0, "shield_regen_per_s": 10.0, "shield_regen_delay_s": 2.0})
	DamageCalc.apply(10.0, "explosive", 0.0, stats, RULES)
	assert_almost_eq(stats.shield, 40.0, 0.0001)
	stats.tick(1.0)
	assert_almost_eq(stats.shield, 40.0, 0.0001, "no regeneration during the delay")
	stats.tick(0.9)
	stats.tick(0.5)
	assert_almost_eq(stats.shield, 45.0, 0.0001)
	stats.tick(10.0)
	assert_eq(stats.shield, 50.0)


func test_dead_targets_take_no_damage() -> void:
	var stats: TargetStats = _stats({"hp": 10.0})
	DamageCalc.apply(10.0, "energy", 0.0, stats, RULES)
	var result: DamageResult = DamageCalc.apply(10.0, "energy", 0.0, stats, RULES)
	assert_eq(result.hull_damage, 0.0)
	assert_false(result.killed)


func test_splash_falloff() -> void:
	assert_almost_eq(DamageCalc.splash_falloff(0.0, 10.0, 0.4), 1.0, 0.0001)
	assert_almost_eq(DamageCalc.splash_falloff(5.0, 10.0, 0.4), 0.7, 0.0001)
	assert_almost_eq(DamageCalc.splash_falloff(10.0, 10.0, 0.4), 0.4, 0.0001)
	assert_eq(DamageCalc.splash_falloff(10.1, 10.0, 0.4), 0.0)


func test_archetype_list_matches_the_factory() -> void:
	var from_factory: Array = WeaponFactory.ARCHETYPES.keys()
	from_factory.sort()
	var listed: Array = Array(WeaponArchetypes.IMPLEMENTED)
	listed.sort()
	assert_eq(listed, from_factory)


func test_every_shipped_weapon_can_be_created() -> void:
	var weapons: Dictionary = GameData.loader.get_category("weapons")
	assert_gt(weapons.size(), 0)
	for weapon_id: String in weapons:
		var weapon: Weapon = WeaponFactory.create(weapons[weapon_id])
		assert_not_null(weapon, weapon_id)
		if weapon != null:
			weapon.free()
