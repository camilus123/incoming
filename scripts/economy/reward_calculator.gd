class_name RewardCalculator
extends RefCounted
## Turns a stage's statistics into credits (spec 3.10). Pure maths, unit
## tested; every number comes from economy.json.


## Returns the itemised reward: a list of
## `{ "id", "label", "detail", "amount" }` in display order.
## `stage_data` supplies the par time; `reward_multiplier` is the difficulty's.
static func calculate(stats: StageStats, stage_data: Dictionary, economy: Dictionary, reward_multiplier: float = 1.0) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var base: Dictionary = economy.get("stage_base", {})
	var stage_base: float = float(base.get("base", 200.0)) + float(base.get("per_stage", 50.0)) * stats.stage
	lines.append(_line("stage_base", "Stage %d cleared" % stats.stage, "", stage_base))
	lines.append(_line("bounties", "Kill bounties", "%d destroyed" % stats.kills, stats.bounty))

	var accuracy: float = stats.accuracy_percent()
	var per_accuracy: float = economy.get("accuracy_bonus_per_percent", 3.0)
	lines.append(_line("accuracy", "Accuracy bonus", "%d %% × %s" % [roundi(accuracy), _trim(per_accuracy)], roundf(accuracy) * per_accuracy))

	var hull: float = stats.hull_percent()
	var per_hull: float = economy.get("hull_bonus_per_percent", 4.0)
	lines.append(_line("hull", "Hull integrity bonus", "%d %% × %s" % [roundi(hull), _trim(per_hull)], roundf(hull) * per_hull))

	var shield_bonus: float = 0.0 if stats.shield_broken else float(economy.get("no_shield_break_bonus", 250.0))
	lines.append(_line("shield", "Shields never broke", "no" if stats.shield_broken else "yes", shield_bonus))

	var par_s: float = stage_data.get("par_time_s", 0.0)
	lines.append(_line("speed", "Speed bonus", "%s (par %s)" % [_clock(stats.time_s), _clock(par_s)], speed_bonus(stats.time_s, par_s, economy)))

	var per_intercept: float = economy.get("intercept_bonus", 15.0)
	lines.append(_line("intercepts", "Intercept bonus", "%d × %s" % [stats.intercepts, _trim(per_intercept)], stats.intercepts * per_intercept))

	if not is_equal_approx(reward_multiplier, 1.0):
		var subtotal: int = total(lines)
		lines.append(_line("difficulty", "Difficulty", "× %s" % _trim(reward_multiplier), subtotal * (reward_multiplier - 1.0)))
	return lines


## Sum of all lines of a breakdown.
static func total(lines: Array[Dictionary]) -> int:
	var sum: int = 0
	for line: Dictionary in lines:
		sum += int(line["amount"])
	return sum


## Speed bonus: the full amount at or below `par × full_bonus_ratio`, nothing
## at or above `par × zero_bonus_ratio`, linear in between.
static func speed_bonus(time_s: float, par_s: float, economy: Dictionary) -> float:
	var rules: Dictionary = economy.get("speed_bonus", {})
	var best_s: float = par_s * float(rules.get("full_bonus_ratio", 0.6))
	var worst_s: float = par_s * float(rules.get("zero_bonus_ratio", 1.2))
	if par_s <= 0.0 or worst_s <= best_s:
		return 0.0
	return float(rules.get("max", 300.0)) * clampf(inverse_lerp(worst_s, best_s, time_s), 0.0, 1.0)


static func _line(id: String, label: String, detail: String, amount: float) -> Dictionary:
	return {"id": id, "label": label, "detail": detail, "amount": int(roundf(amount))}


static func _trim(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 2)


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
