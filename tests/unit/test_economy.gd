extends GutTest
## Tests for the M4 systems: modifier stacking, tech tree rules, the reward
## calculator, the save round trip and the run state (GameState).

const ECONOMY: Dictionary = {
	"stage_base": {"base": 200.0, "per_stage": 50.0},
	"accuracy_bonus_per_percent": 3.0,
	"hull_bonus_per_percent": 4.0,
	"no_shield_break_bonus": 250.0,
	"speed_bonus": {"max": 300.0, "full_bonus_ratio": 0.6, "zero_bonus_ratio": 1.2},
	"intercept_bonus": 15.0,
}
const TREE: Dictionary = {
	"branches": {"a": {"display_name": "A"}},
	"nodes": [
		{"id": "root", "name": "Root", "branch": "a", "cost": 0, "owned_at_start": true, "effects": []},
		{"id": "left_1", "name": "Left 1", "branch": "a", "cost": 600, "requires": {"all_of": ["root"]}, "exclusive_group": "core", "effects": []},
		{"id": "left_2", "name": "Left 2", "branch": "a", "cost": 1100, "requires": {"all_of": ["left_1"]}, "effects": []},
		{"id": "right_1", "name": "Right 1", "branch": "a", "cost": 600, "requires": {"all_of": ["root"]}, "exclusive_group": "core", "effects": []},
		{"id": "right_2", "name": "Right 2", "branch": "a", "cost": 1100, "requires": {"all_of": ["right_1"]}, "effects": []},
		{"id": "shared", "name": "Shared", "branch": "a", "cost": 900, "requires": {"any_of": ["left_1", "right_1"]}, "effects": []},
	],
}
const TEMP_SAVE: String = "user://test_saves/run_test.json"

var _tree: TechTree


func before_each() -> void:
	_tree = TechTree.new(TREE)
	# Tests never touch the player's real save.
	GameState.persistent = false
	GameState.save_path = TEMP_SAVE
	GameState._rebuild_tree()
	GameState.new_run()


func after_all() -> void:
	SaveSystem.delete(TEMP_SAVE)
	GameState.save_path = SaveSystem.DEFAULT_PATH
	GameState._rebuild_tree()
	GameState.new_run()


func _mod(target: String, op: String, value: Variant) -> Dictionary:
	return {"target": target, "op": op, "value": value}


# --- Modifiers ---------------------------------------------------------------

func test_set_add_and_mul() -> void:
	var base: Dictionary = {"capacity": 100.0, "recharge_per_s": 12.0, "delay": 3.0}
	var result: Dictionary = Modifiers.apply(base, "shield", [
		_mod("shield.capacity", "set", 180), _mod("shield.recharge_per_s", "add", 3), _mod("shield.delay", "mul", 0.5)])
	assert_eq(result["capacity"], 180)
	assert_almost_eq(float(result["recharge_per_s"]), 15.0, 0.0001)
	assert_almost_eq(float(result["delay"]), 1.5, 0.0001)
	assert_eq(base["capacity"], 100.0, "the base data is not changed")


func test_stacking_is_set_then_add_then_mul_whatever_the_order() -> void:
	var base: Dictionary = {"damage": 10.0}
	var modifiers: Array[Dictionary] = [
		_mod("weapon.x.damage", "mul", 2.0), _mod("weapon.x.damage", "add", 5), _mod("weapon.x.damage", "set", 20), _mod("weapon.x.damage", "mul", 1.5)]
	assert_almost_eq(float(Modifiers.apply(base, "weapon.x", modifiers)["damage"]), 75.0, 0.0001, "(20 + 5) * 2 * 1.5")
	modifiers.reverse()
	assert_almost_eq(float(Modifiers.apply(base, "weapon.x", modifiers)["damage"]), 75.0, 0.0001)


func test_the_last_set_wins() -> void:
	var result: Dictionary = Modifiers.apply({"capacity": 100.0}, "shield", [_mod("shield.capacity", "set", 180), _mod("shield.capacity", "set", 260)])
	assert_eq(result["capacity"], 260)


func test_wildcards_and_nested_paths() -> void:
	var weapon: Dictionary = {"heat": {"per_shot": 0.1, "cooling_per_s": 0.3}}
	var modifiers: Array[Dictionary] = [_mod("weapon.*.heat.per_shot", "mul", 0.8), _mod("weapon.other.heat.per_shot", "mul", 0.1)]
	var result: Dictionary = Modifiers.apply(weapon, "weapon.pulse_laser", modifiers)
	assert_almost_eq(float(result["heat"]["per_shot"]), 0.08, 0.0001, "the wildcard applies, the other weapon's modifier does not")
	assert_eq(result["heat"]["cooling_per_s"], 0.3)


func test_modifiers_only_touch_their_scope() -> void:
	var result: Dictionary = Modifiers.apply({"capacity": 100.0}, "shield", [_mod("turret.capacity", "set", 1), _mod("shieldx.capacity", "set", 2)])
	assert_eq(result["capacity"], 100.0)
	assert_eq(Modifiers.match_scope("weapon.*.heat.per_shot", "weapon.pulse_laser"), "heat.per_shot")
	assert_eq(Modifiers.match_scope("shield.capacity", "shield"), "capacity")
	assert_eq(Modifiers.match_scope("shield", "shield"), "")


func test_new_fields_strings_and_whole_numbers() -> void:
	var result: Dictionary = Modifiers.apply({"visuals": {"style": "dome"}, "salvo": 4}, "s", [
		_mod("s.visuals.style", "set", "conformal"), _mod("s.min_recharge", "set", 0.25), _mod("s.bonus", "add", 0.1), _mod("s.salvo", "add", 2.0)])
	assert_eq(result["visuals"]["style"], "conformal")
	assert_eq(result["min_recharge"], 0.25)
	assert_almost_eq(float(result["bonus"]), 0.1, 0.0001, "add on a missing field starts from 0")
	assert_eq(typeof(result["salvo"]), TYPE_INT, "whole-number stats stay whole")
	assert_eq(result["salvo"], 6)


# --- Tech tree ---------------------------------------------------------------

func test_prerequisites_and_states() -> void:
	var purchased: Array[String] = ["root"]
	assert_eq(_tree.get_state("root", purchased), TechTree.NodeState.PURCHASED)
	assert_eq(_tree.get_state("left_1", purchased), TechTree.NodeState.AVAILABLE)
	assert_eq(_tree.get_state("left_2", purchased), TechTree.NodeState.LOCKED)
	assert_eq(_tree.get_state("shared", purchased), TechTree.NodeState.LOCKED, "needs one of the two branches")
	purchased.append("left_1")
	assert_eq(_tree.get_state("left_2", purchased), TechTree.NodeState.AVAILABLE)
	assert_eq(_tree.get_state("shared", purchased), TechTree.NodeState.AVAILABLE, "any_of is met by one branch")


func test_exclusive_group_locks_the_other_branch_and_everything_behind_it() -> void:
	var purchased: Array[String] = ["root", "left_1"]
	assert_eq(_tree.get_state("right_1", purchased), TechTree.NodeState.EXCLUDED)
	assert_eq(_tree.get_state("right_2", purchased), TechTree.NodeState.EXCLUDED, "only reachable through an excluded node")
	assert_eq(_tree.get_state("shared", purchased), TechTree.NodeState.AVAILABLE, "still reachable through the chosen branch")
	assert_false(_tree.can_buy("right_1", purchased, 99999))


func test_buying_needs_credits() -> void:
	var purchased: Array[String] = ["root"]
	assert_false(_tree.can_buy("left_1", purchased, 599))
	assert_true(_tree.can_buy("left_1", purchased, 600))
	assert_false(_tree.can_buy("left_2", purchased, 99999), "prerequisite missing")
	assert_false(_tree.can_buy("nope", purchased, 99999))


func test_refund_rules() -> void:
	var purchased: Array[String] = ["root", "left_1", "left_2", "shared"]
	assert_false(_tree.can_refund("root", purchased), "starting nodes cannot be refunded")
	assert_false(_tree.can_refund("left_1", purchased), "left_2 and shared depend on it")
	assert_true(_tree.can_refund("left_2", purchased))
	assert_true(_tree.can_refund("shared", purchased))
	assert_eq(_tree.refund_value("left_2", 0.75), 825)
	assert_eq(_tree.refund_value("left_2", 1.0), 1100)
	# Refunding the branch's first node reopens the other branch.
	var after_respec: Array[String] = ["root"]
	assert_eq(_tree.get_state("right_1", after_respec), TechTree.NodeState.AVAILABLE)


func test_validation_finds_cycles_unknown_references_and_unreachable_nodes() -> void:
	assert_eq(TechTree.find_problems(TREE).size(), 0)
	var broken: Dictionary = TREE.duplicate(true)
	broken["nodes"].append({"id": "loop_a", "name": "A", "branch": "a", "cost": 1, "requires": {"all_of": ["loop_b"]}, "effects": []})
	broken["nodes"].append({"id": "loop_b", "name": "B", "branch": "a", "cost": 1, "requires": {"all_of": ["loop_a"]}, "effects": []})
	broken["nodes"].append({"id": "ghost", "name": "G", "branch": "nowhere", "cost": 1, "requires": {"all_of": ["missing"]}, "effects": []})
	var text: String = JSON.stringify(TechTree.find_problems(broken))
	assert_string_contains(text, "cycle")
	assert_string_contains(text, "unknown node")
	assert_string_contains(text, "unknown branch")
	assert_string_contains(text, "never be reached")


func test_the_shipped_tree_is_sound() -> void:
	var config: Dictionary = GameData.loader.get_config("techtree")
	assert_eq(TechTree.find_problems(config).size(), 0)
	assert_gte((config["nodes"] as Array).size(), 79)


# --- Rewards -----------------------------------------------------------------

func _stats() -> StageStats:
	var stats: StageStats = StageStats.new()
	stats.stage = 3
	stats.kills = 40
	stats.bounty = 310
	stats.shots_fired = 100
	stats.shots_hit = 60
	stats.intercepts = 4
	stats.time_s = 72.0
	stats.hull_max = 200.0
	stats.hull_end = 150.0
	return stats


func _amount(lines: Array[Dictionary], id: String) -> int:
	for line: Dictionary in lines:
		if line["id"] == id:
			return line["amount"]
	return -1


func test_reward_breakdown_matches_the_spec_formulas() -> void:
	var lines: Array[Dictionary] = RewardCalculator.calculate(_stats(), {"par_time_s": 120.0}, ECONOMY)
	assert_eq(_amount(lines, "stage_base"), 350, "200 + 50 x 3")
	assert_eq(_amount(lines, "bounties"), 310)
	assert_eq(_amount(lines, "accuracy"), 180, "60 % x 3")
	assert_eq(_amount(lines, "hull"), 300, "75 % x 4")
	assert_eq(_amount(lines, "shield"), 250)
	assert_eq(_amount(lines, "speed"), 300, "72 s is exactly par x 0.6")
	assert_eq(_amount(lines, "intercepts"), 60, "4 x 15")
	assert_eq(RewardCalculator.total(lines), 1750)


func test_shield_break_and_slow_clear_lose_their_bonuses() -> void:
	var stats: StageStats = _stats()
	stats.shield_broken = true
	stats.time_s = 144.0
	var lines: Array[Dictionary] = RewardCalculator.calculate(stats, {"par_time_s": 120.0}, ECONOMY)
	assert_eq(_amount(lines, "shield"), 0)
	assert_eq(_amount(lines, "speed"), 0, "at par x 1.2 the bonus is gone")


func test_speed_bonus_is_linear_between_the_two_ratios() -> void:
	assert_almost_eq(RewardCalculator.speed_bonus(108.0, 120.0, ECONOMY), 150.0, 0.001, "halfway between 72 s and 144 s")
	assert_almost_eq(RewardCalculator.speed_bonus(10.0, 120.0, ECONOMY), 300.0, 0.001)
	assert_eq(RewardCalculator.speed_bonus(60.0, 0.0, ECONOMY), 0.0, "no par time, no bonus")


func test_difficulty_multiplier_adds_a_line() -> void:
	var lines: Array[Dictionary] = RewardCalculator.calculate(_stats(), {"par_time_s": 120.0}, ECONOMY, 1.1)
	assert_eq(_amount(lines, "difficulty"), 175)
	assert_eq(RewardCalculator.total(lines), 1925)


# --- Saving ------------------------------------------------------------------

func test_save_round_trip() -> void:
	var data: Dictionary = {"stage": 4, "credits": 2350, "purchased": ["a", "b"], "loadout": {"primary": "pulse_laser"}, "hull": 120.5, "statistics": {"kills": 99}}
	assert_eq(SaveSystem.save_to(TEMP_SAVE, data), OK)
	var loaded: Dictionary = SaveSystem.load_from(TEMP_SAVE)
	assert_eq(int(loaded["save_version"]), SaveSystem.CURRENT_VERSION)
	assert_eq(int(loaded["stage"]), 4)
	assert_eq(int(loaded["credits"]), 2350)
	assert_eq(loaded["purchased"], ["a", "b"])
	assert_eq(loaded["loadout"]["primary"], "pulse_laser")
	assert_almost_eq(float(loaded["hull"]), 120.5, 0.0001)
	assert_eq(int(loaded["statistics"]["kills"]), 99)


func test_missing_damaged_and_future_saves_are_ignored() -> void:
	assert_eq(SaveSystem.load_from("user://test_saves/none.json"), {})
	var file: FileAccess = FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_eq(SaveSystem.load_from(TEMP_SAVE), {})
	assert_eq(SaveSystem.migrate({"save_version": SaveSystem.CURRENT_VERSION + 1, "stage": 2}), {}, "a save from a newer game")
	assert_eq(int(SaveSystem.migrate({"stage": 2})["save_version"]), SaveSystem.CURRENT_VERSION, "an unversioned save is upgraded")


func test_run_state_survives_save_and_load() -> void:
	GameState.persistent = true
	GameState.credits = 5000
	assert_true(GameState.buy("bastion_1"))
	assert_true(GameState.buy("pulse_laser_mk2"))
	GameState.stage = 3
	GameState.hull = 123.0
	GameState.save_run()
	GameState.new_run()
	assert_eq(GameState.stage, 1)
	assert_true(GameState.load_run())
	GameState.persistent = false
	assert_eq(GameState.stage, 3)
	assert_eq(GameState.credits, 5000 - 600 - 500)
	assert_true(GameState.purchased.has("bastion_1"))
	assert_true(GameState.purchased.has("pulse_laser_mk2"))
	assert_almost_eq(GameState.get_current_hull(), 123.0, 0.0001)
	assert_eq(GameState.loadout["primary"], "pulse_laser")


# --- Run state with the shipped tree -----------------------------------------

func test_new_run_starts_with_the_spec_values() -> void:
	assert_eq(GameState.credits, 1500)
	assert_eq(GameState.stage, 1)
	assert_true(GameState.purchased.has("basic_deflector"))
	assert_eq(GameState.get_owned_weapons(), ["pulse_laser", "micro_missile_pod"] as Array[String])
	assert_eq(GameState.get_shield_data()["capacity"], 100.0)


func test_buying_bastion_changes_the_shield_and_locks_flicker() -> void:
	GameState.credits = 99999
	assert_true(GameState.buy("bastion_1"))
	var shield: Dictionary = GameState.get_shield_data()
	assert_eq(float(shield["capacity"]), 180.0)
	assert_eq(float(shield["recharge_per_s"]), 9.0)
	assert_eq(float(shield["recharge_delay_s"]), 3.5)
	assert_eq(GameState.get_node_state("flicker_1"), TechTree.NodeState.EXCLUDED)
	assert_false(GameState.buy("flicker_1"))
	assert_true(GameState.buy("bastion_2"))
	assert_eq(float(GameState.get_shield_data()["capacity"]), 260.0)
	# Respec at the configured ratio (100 % for now), deepest node first.
	assert_false(GameState.refund("bastion_1"), "bastion_2 depends on it")
	assert_true(GameState.refund("bastion_2"))
	assert_true(GameState.refund("bastion_1"))
	assert_eq(GameState.credits, 99999)
	assert_eq(GameState.get_node_state("flicker_1"), TechTree.NodeState.AVAILABLE)


func test_flicker_switches_the_shield_to_the_conformal_look() -> void:
	GameState.credits = 99999
	assert_true(GameState.buy("flicker_1"))
	var shield: Dictionary = GameState.get_shield_data()
	assert_eq(float(shield["capacity"]), 80.0)
	assert_eq(shield["visuals"]["style"], "conformal")


func test_weapon_and_core_upgrades_apply() -> void:
	GameState.credits = 99999
	var base_damage: float = GameState.get_weapon_data("pulse_laser")["damage"]
	var base_heat: float = GameState.get_weapon_data("pulse_laser")["heat"]["per_shot"]
	GameState.buy("pulse_laser_mk2")
	GameState.buy("fast_cooling")
	var laser: Dictionary = GameState.get_weapon_data("pulse_laser")
	assert_almost_eq(float(laser["damage"]), base_damage * 1.25, 0.0001)
	assert_almost_eq(float(laser["heat"]["per_shot"]), base_heat * 0.85 * 0.8, 0.0001, "Mk II and Fast Cooling multiply")
	assert_eq(laser["display_name"], "Pulse Laser Mk II")
	GameState.buy("micro_missile_pod_mk2")
	assert_eq(int(GameState.get_weapon_data("micro_missile_pod")["homing"]["salvo_size"]), 6)
	GameState.buy("reactor_1")
	GameState.buy("reactor_2")
	assert_almost_eq(GameState.get_reactor_bonus(), 0.2, 0.0001)
	GameState.buy("armoured_hull_1")
	GameState.buy("armoured_hull_2")
	assert_almost_eq(GameState.get_max_hull(), 300.0, 0.0001, "+25 % of the base twice")
	GameState.buy("targeting_computer")
	assert_true(GameState.get_hud_flags().get("enemy_health_bars", false))
	GameState.buy("bastion_1")
	GameState.buy("shield_harmonics")
	assert_almost_eq(float(GameState.get_turret_data()["resistances"]["energy"]), 0.2, 0.0001)


func test_special_effects_are_collected_and_implemented() -> void:
	GameState.credits = 99999
	for id: String in ["bastion_1", "bastion_2", "bastion_3", "bastion_4", "aegis_bulwark"]:
		assert_true(GameState.buy(id), id)
	var names: Array[String] = []
	for effect: Dictionary in GameState.get_special_effects():
		names.append(effect["effect"])
	assert_eq(names, ["damage_reduction_while_shielded", "aegis_bulwark"] as Array[String])
	assert_eq(float(GameState.get_shield_data()["min_recharge_multiplier"]), 0.25)
	var from_registry: Array = EffectRegistry.EFFECTS.keys()
	from_registry.sort()
	var listed: Array = Array(EffectNames.IMPLEMENTED)
	listed.sort()
	assert_eq(listed, from_registry)


func test_bought_weapons_can_be_equipped_in_their_slot_only() -> void:
	GameState.credits = 99999
	assert_true(GameState.buy("chain_gun"))
	assert_true(GameState.get_owned_weapons().has("chain_gun"))
	assert_true(GameState.equip("primary", "chain_gun"))
	assert_false(GameState.equip("alternate", "chain_gun"), "a primary weapon does not fit the alternate slot")
	assert_false(GameState.equip("primary", "railgun"), "not owned")
	# Refunding the weapon puts the default back in the slot.
	assert_true(GameState.refund("chain_gun"))
	assert_eq(GameState.loadout["primary"], "pulse_laser")


func test_hull_repair_costs_credits_and_can_be_partial() -> void:
	GameState.hull = 100.0
	assert_eq(GameState.get_repair_cost(), 200, "100 missing points at 2 cr")
	GameState.credits = 50
	assert_eq(GameState.repair_hull(), 50)
	assert_almost_eq(GameState.get_current_hull(), 125.0, 0.0001)
	GameState.credits = 1000
	assert_eq(GameState.repair_hull(), 150)
	assert_almost_eq(GameState.get_current_hull(), 200.0, 0.0001)
	assert_eq(GameState.credits, 850)
	assert_eq(GameState.repair_hull(), 0, "nothing left to repair")


func test_tooltip_preview_shows_before_and_after() -> void:
	var lines: Array[Dictionary] = GameState.preview_node("bastion_1")
	var found: bool = false
	for line: Dictionary in lines:
		if str(line["label"]).ends_with("capacity"):
			found = true
			assert_eq(float(line["before"]), 100.0)
			assert_eq(float(line["after"]), 180.0)
	assert_true(found)


# --- Adding a node with JSON only --------------------------------------------

func test_a_node_added_in_json_works_without_code() -> void:
	# Check the fixture against the same schema the game uses for tree nodes.
	var report: DataReport = DataReport.new()
	var schema: Dictionary = DataLoader.read_json("res://data/schemas/techtree.schema.json", report)
	var raw: Variant = DataLoader.read_json("res://tests/fixtures/extra_node.json", report)
	var extra: Variant = DataSchema.validate(raw, schema["fields"]["nodes"]["items"], "extra_node.json", report)
	assert_eq(report.error_count(), 0, report.format_text())

	var config: Dictionary = GameData.loader.get_config("techtree").duplicate(true)
	config["nodes"].append(extra)
	assert_eq(TechTree.find_problems(config).size(), 0, "the new node fits into the tree")

	GameState.tree = TechTree.new(config)
	GameState.new_run()
	GameState.credits = 5000
	assert_eq(GameState.get_node_state("overcharged_capacitors"), TechTree.NodeState.LOCKED)
	assert_true(GameState.buy("reactor_1"))
	assert_true(GameState.buy("overcharged_capacitors"))
	assert_eq(GameState.credits, 5000 - 800 - 750)
	assert_eq(float(GameState.get_shield_data()["capacity"]), 150.0)
	assert_almost_eq(float(GameState.get_weapon_data("pulse_laser")["damage"]), 9.9, 0.0001)
