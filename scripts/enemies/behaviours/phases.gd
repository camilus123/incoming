extends EnemyBehaviour
## Module "phases": changes the enemy's behaviour as its hull drops (bosses).
## Parameters:
##   phases: a list of
##     { "below_hp_fraction": 0.66,
##       "enable_attacks": [ids], "disable_attacks": [ids],
##       "enable_spawn": true, "speed_mult": 1.2, "message": "text" }
## Each phase triggers once, in order, when hp falls below its fraction.

var _next_phase: int = 0


func _on_setup() -> void:
	_next_phase = 0


func tick(_delta_s: float) -> void:
	var phases: Array = params.get("phases", [])
	while _next_phase < phases.size():
		var phase: Dictionary = phases[_next_phase]
		if enemy.stats.hp / enemy.stats.max_hp > float(phase.get("below_hp_fraction", 0.0)):
			return
		_next_phase += 1
		for attack_id: Variant in phase.get("enable_attacks", []):
			enemy.set_attack_enabled(str(attack_id), true)
		for attack_id: Variant in phase.get("disable_attacks", []):
			enemy.set_attack_enabled(str(attack_id), false)
		if phase.has("enable_spawn"):
			enemy.spawn_enabled = phase["enable_spawn"]
		if phase.has("speed_mult"):
			enemy.speed_mps *= float(phase["speed_mult"])
		if phase.has("message"):
			EventBus.ui_message.emit(phase["message"])
