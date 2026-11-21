extends GutTest
## Tests for PowerSystem (power-split maths) and ShieldState.

const POWER_CONFIG: Dictionary = {
	"shield_share": {"default": 0.5, "step": 0.1, "min": 0.0, "max": 1.0},
	"shield_recharge_multiplier": {"at_zero_share": 0.0, "at_full_share": 2.0},
	"weapon_output_multiplier": {"at_zero_share": 0.5, "at_full_share": 1.5},
}

var _power: PowerSystem
var _shield: ShieldState


func before_each() -> void:
	_power = PowerSystem.new()
	_power.configure(POWER_CONFIG)
	_shield = ShieldState.new()
	_shield.configure({"capacity": 100.0, "recharge_per_s": 12.0, "recharge_delay_s": 3.0})


func test_default_split_is_neutral() -> void:
	assert_almost_eq(_power.shield_share, 0.5, 0.0001)
	assert_almost_eq(_power.shield_recharge_multiplier(), 1.0, 0.0001)
	assert_almost_eq(_power.weapon_output_multiplier(), 1.0, 0.0001)


func test_full_weapons() -> void:
	for step: int in 5:
		assert_true(_power.shift_to_weapons())
	assert_almost_eq(_power.shield_share, 0.0, 0.0001)
	assert_almost_eq(_power.shield_recharge_multiplier(), 0.0, 0.0001, "no recharge at 0 % shield share")
	assert_almost_eq(_power.weapon_output_multiplier(), 1.5, 0.0001)
	assert_false(_power.shift_to_weapons(), "cannot go past the limit")


func test_full_shields() -> void:
	for step: int in 5:
		_power.shift_to_shields()
	assert_almost_eq(_power.shield_share, 1.0, 0.0001)
	assert_almost_eq(_power.shield_recharge_multiplier(), 2.0, 0.0001)
	assert_almost_eq(_power.weapon_output_multiplier(), 0.5, 0.0001)
	assert_false(_power.shift_to_shields())


func test_each_step_changes_both_multipliers_linearly() -> void:
	_power.shift_to_shields()
	assert_almost_eq(_power.shield_share, 0.6, 0.0001)
	assert_almost_eq(_power.shield_recharge_multiplier(), 1.2, 0.0001)
	assert_almost_eq(_power.weapon_output_multiplier(), 0.9, 0.0001)


func test_many_steps_do_not_drift() -> void:
	for round_trip: int in 50:
		for step: int in 10:
			_power.shift_to_shields()
		for step: int in 10:
			_power.shift_to_weapons()
	assert_eq(_power.shield_share, 0.0)
	for step: int in 5:
		_power.shift_to_shields()
	assert_eq(_power.shield_share, 0.5)


func test_reset_returns_to_default() -> void:
	_power.shift_to_weapons()
	_power.shift_to_weapons()
	assert_true(_power.reset())
	assert_almost_eq(_power.shield_share, 0.5, 0.0001)
	assert_false(_power.reset(), "already at the default")


func test_reactor_bonus_raises_the_top_of_both_curves() -> void:
	_power.reactor_bonus = 0.1
	for step: int in 5:
		_power.shift_to_shields()
	assert_almost_eq(_power.shield_recharge_multiplier(), 2.2, 0.0001)
	assert_almost_eq(_power.weapon_output_multiplier(), 0.5, 0.0001, "the low end is unchanged")
	for step: int in 10:
		_power.shift_to_weapons()
	assert_almost_eq(_power.weapon_output_multiplier(), 1.65, 0.0001)


func test_custom_step_and_limits() -> void:
	_power.configure({"shield_share": {"default": 0.5, "step": 0.25, "min": 0.25, "max": 0.75}})
	_power.shift_to_shields()
	assert_almost_eq(_power.shield_share, 0.75, 0.0001)
	assert_false(_power.shift_to_shields())


func test_shield_absorbs_before_the_hull() -> void:
	assert_eq(_shield.absorb(30.0), 0.0)
	assert_almost_eq(_shield.charge, 70.0, 0.0001)
	assert_almost_eq(_shield.absorb(100.0), 30.0, 0.0001, "the overflow reaches the hull")
	assert_eq(_shield.charge, 0.0)
	assert_false(_shield.is_up())
	assert_almost_eq(_shield.absorb(15.0), 15.0, 0.0001, "an empty shield absorbs nothing")


func test_shield_recharges_only_after_the_delay() -> void:
	_shield.absorb(50.0)
	_shield.tick(2.9, 1.0)
	assert_almost_eq(_shield.charge, 50.0, 0.0001)
	_shield.tick(0.1, 1.0)
	_shield.tick(1.0, 1.0)
	assert_almost_eq(_shield.charge, 63.2, 0.01)


func test_a_hit_restarts_the_delay() -> void:
	_shield.absorb(50.0)
	_shield.tick(2.5, 1.0)
	_shield.absorb(1.0)
	_shield.tick(2.5, 1.0)
	assert_almost_eq(_shield.charge, 49.0, 0.0001)


func test_recharge_scales_with_the_power_multiplier() -> void:
	_shield.absorb(80.0)
	_shield.tick(3.0, 0.0)
	_shield.tick(1.0, 2.0)
	assert_almost_eq(_shield.charge, 44.0, 0.0001, "12/s x2 for one second")


func test_no_recharge_at_zero_multiplier_but_charge_is_kept() -> void:
	_shield.absorb(40.0)
	_shield.tick(60.0, 0.0)
	assert_almost_eq(_shield.charge, 60.0, 0.0001)


func test_minimum_recharge_overrides_a_zero_split() -> void:
	_shield.min_recharge_multiplier = 0.25
	_shield.absorb(40.0)
	_shield.tick(2.99, 0.0)
	_shield.tick(1.0, 0.0)
	assert_almost_eq(_shield.charge, 63.0, 0.0001, "25 % of 12/s")


func test_break_and_restore_events() -> void:
	_shield.absorb(100.0)
	assert_eq(_shield.tick(0.1, 1.0), -1, "reports the break once")
	assert_eq(_shield.tick(0.1, 1.0), 0)
	var restored: int = 0
	for step: int in 200:
		if _shield.tick(0.1, 1.0) == 1:
			restored += 1
	assert_eq(restored, 1, "reports empty-to-full once")
	assert_eq(_shield.charge, 100.0)


func test_refill() -> void:
	_shield.absorb(100.0)
	_shield.refill()
	assert_eq(_shield.get_fraction(), 1.0)


func test_shipped_shield_matches_the_spec() -> void:
	var data: Dictionary = GameData.loader.get_entry("shields", "basic_deflector")
	assert_eq(data["capacity"], 100.0)
	assert_eq(data["recharge_per_s"], 12.0)
	assert_eq(data["recharge_delay_s"], 3.0)
