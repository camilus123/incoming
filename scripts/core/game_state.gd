extends Node
## Autoload "GameState": the player's run. Credits, the stage reached,
## purchased tech tree nodes, the weapon loadout, hull damage and totals.
##
## It also answers "what are my stats right now?": weapon, shield and turret
## data with every purchased modifier applied. The turret and the shop read
## those; nothing else stores upgraded numbers.

## Emitted whenever credits, purchases, loadout or hull change.
signal changed()

const SLOTS: PackedStringArray = ["primary", "alternate"]
## Node state used by the shop for nodes whose weapon is not in this build yet.
const STATE_UNAVAILABLE: int = -1

var credits: int = 0
## The next stage to play (1-based).
var stage: int = 1
## Purchased node ids in order of purchase (starting nodes first).
var purchased: Array[String] = []
## Slot -> weapon id.
var loadout: Dictionary = {}
## Current hull points; negative means "full".
var hull: float = -1.0
## Run totals for the game-over screen and later achievements.
var statistics: Dictionary = {}
## When false nothing is written to disk (test range, automated demo, debug starts).
var persistent: bool = true
var save_path: String = SaveSystem.DEFAULT_PATH

var tree: TechTree = TechTree.new()

var _modifier_cache: Array[Dictionary] = []
var _cache_valid: bool = false


func _ready() -> void:
	EventBus.data_reloaded.connect(_on_data_reloaded)
	_rebuild_tree()
	if not load_run():
		new_run()


# --- Run lifecycle -----------------------------------------------------------

## Starts a fresh run: starting credits, starting nodes, default loadout.
func new_run() -> void:
	var economy: Dictionary = GameData.loader.get_config("economy")
	credits = economy.get("starting_credits", 1500)
	stage = 1
	purchased = tree.get_start_nodes()
	hull = -1.0
	statistics = {"stages_cleared": 0, "kills": 0, "credits_earned": 0}
	loadout = {}
	var defaults: Dictionary = GameData.loader.get_config("turret").get("default_loadout", {})
	for slot: String in SLOTS:
		loadout[slot] = defaults.get(slot, "")
	_touch()


func has_save() -> bool:
	return SaveSystem.exists(save_path)


## Writes the run to disk (autosave at every shop visit).
func save_run() -> void:
	if persistent:
		SaveSystem.save_to(save_path, to_save_data())


## Loads the saved run. Returns false if there is none or it is unusable.
func load_run() -> bool:
	if not persistent:
		return false
	var data: Dictionary = SaveSystem.load_from(save_path)
	if data.is_empty():
		return false
	apply_save_data(data)
	return true


## The run as plain data for the save file.
func to_save_data() -> Dictionary:
	return {
		"stage": stage,
		"credits": credits,
		"purchased": purchased.duplicate(),
		"loadout": loadout.duplicate(),
		"hull": hull,
		"statistics": statistics.duplicate(true),
	}


## Restores the run from save data. Nodes and weapons that no longer exist in
## the data files are dropped, so an old save survives content changes.
func apply_save_data(data: Dictionary) -> void:
	stage = maxi(1, int(data.get("stage", 1)))
	credits = maxi(0, int(data.get("credits", 0)))
	hull = float(data.get("hull", -1.0))
	statistics = (data.get("statistics", {}) as Dictionary).duplicate(true)
	purchased = tree.get_start_nodes()
	for id: Variant in data.get("purchased", []):
		if tree.has_node(str(id)) and not purchased.has(str(id)):
			purchased.append(str(id))
	_cache_valid = false
	loadout = {}
	var saved_loadout: Dictionary = data.get("loadout", {})
	var defaults: Dictionary = GameData.loader.get_config("turret").get("default_loadout", {})
	for slot: String in SLOTS:
		var weapon_id: String = saved_loadout.get(slot, "")
		loadout[slot] = weapon_id if can_equip(slot, weapon_id) else defaults.get(slot, "")
	_touch()


# --- Tech tree ---------------------------------------------------------------

## State of a node for the shop: a TechTree.NodeState, or STATE_UNAVAILABLE if
## the node needs a weapon that is not in this build yet.
func get_node_state(id: String) -> int:
	var state: int = tree.get_state(id, purchased)
	if state != TechTree.NodeState.PURCHASED and not is_node_in_build(id):
		return STATE_UNAVAILABLE
	return state


## False if the node unlocks or modifies a weapon that has no data or no
## implemented archetype yet.
func is_node_in_build(id: String) -> bool:
	for effect: Dictionary in tree.get_node(id).get("effects", []):
		var weapon_id: String = effect.get("unlock", "")
		if weapon_id.is_empty() and str(effect.get("target", "")).begins_with("weapon."):
			weapon_id = str(effect["target"]).split(".")[1]
		if weapon_id.is_empty() or weapon_id == "*":
			continue
		var weapon: Dictionary = GameData.loader.get_entry("weapons", weapon_id)
		if weapon.is_empty() or not WeaponArchetypes.IMPLEMENTED.has(weapon.get("archetype", "")):
			return false
	return true


func can_buy(id: String) -> bool:
	return is_node_in_build(id) and tree.can_buy(id, purchased, credits)


## Buys a node. Returns false if it is not available or too expensive.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	credits -= tree.get_cost(id)
	purchased.append(id)
	_touch()
	return true


func can_refund(id: String) -> bool:
	return tree.can_refund(id, purchased)


func get_refund_value(id: String) -> int:
	return tree.refund_value(id, GameData.loader.get_config("economy").get("respec_refund_ratio", 0.75))


## Refunds a node (respec). Weapons that are no longer owned are unequipped.
func refund(id: String) -> bool:
	if not can_refund(id):
		return false
	credits += get_refund_value(id)
	purchased.erase(id)
	_cache_valid = false
	var defaults: Dictionary = GameData.loader.get_config("turret").get("default_loadout", {})
	for slot: String in SLOTS:
		if not can_equip(slot, loadout.get(slot, "")):
			loadout[slot] = defaults.get(slot, "")
	_touch()
	return true


# --- Effective stats ---------------------------------------------------------

## All modifier effects of the purchased nodes, in order of purchase.
func get_modifiers() -> Array[Dictionary]:
	if not _cache_valid:
		_modifier_cache = Modifiers.from_nodes(_nodes_of(purchased))
		_cache_valid = true
	return _modifier_cache


## A weapon's data with all purchased upgrades applied ({} if unknown).
func get_weapon_data(weapon_id: String) -> Dictionary:
	return _weapon_data_with(weapon_id, get_modifiers())


## The shield's data with all purchased upgrades applied.
func get_shield_data() -> Dictionary:
	return _shield_data_with(get_modifiers())


## The turret config (turret.json) with all purchased upgrades applied.
func get_turret_data() -> Dictionary:
	return _turret_data_with(get_modifiers())


func get_max_hull() -> float:
	return max_hull_of(get_turret_data())


## Maximum hull for a (modified) turret config.
static func max_hull_of(turret_data: Dictionary) -> float:
	var hull_block: Dictionary = turret_data.get("hull", {})
	return float(hull_block.get("max", 200.0)) * (1.0 + float(hull_block.get("max_bonus", 0.0)))


func get_current_hull() -> float:
	var max_hull: float = get_max_hull()
	return max_hull if hull < 0.0 else minf(hull, max_hull)


## Reactor upgrades: how much the top of both power curves is raised.
func get_reactor_bonus() -> float:
	return float(Modifiers.apply({"reactor_bonus": 0.0}, "power", get_modifiers())["reactor_bonus"])


## HUD features switched on by upgrades, e.g. `{ "enemy_health_bars": true }`.
func get_hud_flags() -> Dictionary:
	return Modifiers.apply({}, "hud", get_modifiers())


## Special effects of the purchased nodes: `[{ "effect": name, "params": {...} }]`.
func get_special_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tree_node: Dictionary in _nodes_of(purchased):
		for effect: Dictionary in tree_node.get("effects", []):
			if effect.has("effect"):
				result.append(effect)
	return result


## Before/after values of every stat a node would change, for the shop
## tooltip: `[{ "label", "before", "after" }]`.
func preview_node(id: String) -> Array[Dictionary]:
	var tree_node: Dictionary = tree.get_node(id)
	var with_node: Array[String] = purchased.duplicate()
	if not with_node.has(id):
		with_node.append(id)
	var without_node: Array[String] = purchased.duplicate()
	without_node.erase(id)
	var before: Array[Dictionary] = Modifiers.from_nodes(_nodes_of(without_node))
	var after: Array[Dictionary] = Modifiers.from_nodes(_nodes_of(with_node))
	var lines: Array[Dictionary] = []
	var seen: Dictionary = {}
	for effect: Dictionary in tree_node.get("effects", []):
		if not effect.has("target"):
			continue
		var target: String = effect["target"]
		for scope: String in _scopes_for(target):
			var path: String = Modifiers.match_scope(target, scope)
			var key: String = scope + "." + path
			if path.is_empty() or seen.has(key) or path.ends_with("display_name"):
				continue
			seen[key] = true
			var scope_before: Dictionary = _scope_data(scope, before)
			if scope.begins_with("weapon.") and scope_before.is_empty():
				continue  # The weapon is not in this build yet.
			lines.append({
				"label": _describe_target(scope, path),
				"before": Modifiers.get_path_value(scope_before, path, null),
				"after": Modifiers.get_path_value(_scope_data(scope, after), path, null),
			})
	return lines


# --- Loadout and hull --------------------------------------------------------

## Ids of the weapons the player owns (unlocked by purchased nodes).
func get_owned_weapons() -> Array[String]:
	var owned: Array[String] = []
	for tree_node: Dictionary in _nodes_of(purchased):
		for effect: Dictionary in tree_node.get("effects", []):
			var weapon_id: String = effect.get("unlock", "")
			if not weapon_id.is_empty() and not owned.has(weapon_id):
				owned.append(weapon_id)
	return owned


func can_equip(slot: String, weapon_id: String) -> bool:
	if weapon_id.is_empty() or not get_owned_weapons().has(weapon_id):
		return false
	var weapon: Dictionary = GameData.loader.get_entry("weapons", weapon_id)
	return (weapon.get("allowed_slots", []) as Array).has(slot) and WeaponArchetypes.IMPLEMENTED.has(weapon.get("archetype", ""))


func equip(slot: String, weapon_id: String) -> bool:
	if not can_equip(slot, weapon_id):
		return false
	loadout[slot] = weapon_id
	_touch()
	return true


## Credits needed to repair the hull completely.
func get_repair_cost() -> int:
	var missing: float = get_max_hull() - get_current_hull()
	return int(ceilf(missing * float(GameData.loader.get_config("economy").get("hull_repair", {}).get("cost_per_point", 2.0))))


## Repairs as much hull as the credits allow. Returns the credits spent.
func repair_hull() -> int:
	var cost_per_point: float = GameData.loader.get_config("economy").get("hull_repair", {}).get("cost_per_point", 2.0)
	var full_cost: int = get_repair_cost()
	if full_cost <= 0 or credits <= 0:
		return 0
	var spent: int = mini(full_cost, credits)
	if spent >= full_cost or cost_per_point <= 0.0:
		hull = -1.0
	else:
		hull = get_current_hull() + spent / cost_per_point
	credits -= spent
	_touch()
	return spent


func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	statistics["credits_earned"] = int(statistics.get("credits_earned", 0)) + maxi(0, amount)
	EventBus.credits_changed.emit(credits)
	_touch()


# --- Internals ---------------------------------------------------------------

func _touch() -> void:
	_cache_valid = false
	changed.emit()


func _rebuild_tree() -> void:
	tree = TechTree.new(GameData.loader.get_config("techtree"))
	_cache_valid = false


func _on_data_reloaded(_report: DataReport) -> void:
	_rebuild_tree()
	var kept: Array[String] = tree.get_start_nodes()
	for id: String in purchased:
		if tree.has_node(id) and not kept.has(id):
			kept.append(id)
	purchased = kept
	_touch()


func _nodes_of(ids: Array[String]) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for id: String in ids:
		if tree.has_node(id):
			nodes.append(tree.get_node(id))
	return nodes


func _weapon_data_with(weapon_id: String, modifiers: Array[Dictionary]) -> Dictionary:
	var base: Dictionary = GameData.loader.get_entry("weapons", weapon_id)
	return {} if base.is_empty() else Modifiers.apply(base, "weapon." + weapon_id, modifiers)


func _shield_data_with(modifiers: Array[Dictionary]) -> Dictionary:
	var shield_id: String = GameData.loader.get_config("turret").get("default_loadout", {}).get("shield", "")
	return Modifiers.apply(GameData.loader.get_entry("shields", shield_id), "shield", modifiers)


func _turret_data_with(modifiers: Array[Dictionary]) -> Dictionary:
	var base: Dictionary = GameData.loader.get_config("turret").duplicate(true)
	if not base.has("resistances"):
		base["resistances"] = {"energy": 0.0, "kinetic": 0.0, "explosive": 0.0}
	return Modifiers.apply(base, "turret", modifiers)


## The scopes a modifier target touches. A wildcard weapon target is shown for
## the equipped weapons.
func _scopes_for(target: String) -> Array[String]:
	var parts: PackedStringArray = target.split(".")
	if parts[0] != "weapon":
		return [parts[0]]
	if parts.size() > 1 and parts[1] != "*":
		return ["weapon." + parts[1]]
	var scopes: Array[String] = []
	for slot: String in SLOTS:
		if not str(loadout.get(slot, "")).is_empty():
			scopes.append("weapon." + str(loadout[slot]))
	return scopes


func _scope_data(scope: String, modifiers: Array[Dictionary]) -> Dictionary:
	if scope.begins_with("weapon."):
		return _weapon_data_with(scope.trim_prefix("weapon."), modifiers)
	match scope:
		"shield":
			return _shield_data_with(modifiers)
		"turret":
			return _turret_data_with(modifiers)
		"power":
			return Modifiers.apply({"reactor_bonus": 0.0}, "power", modifiers)
		"hud":
			return Modifiers.apply({}, "hud", modifiers)
	return {}


func _describe_target(scope: String, path: String) -> String:
	var subject: String = scope.capitalize()
	if scope.begins_with("weapon."):
		subject = GameData.loader.get_entry("weapons", scope.trim_prefix("weapon.")).get("display_name", scope)
	return "%s: %s" % [subject, path.replace(".", " ").replace("_", " ")]
