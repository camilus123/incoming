extends Weapon
## Archetype "hitscan_pulse": instant-hit shots at a fixed rate with a visible
## bolt (Pulse Laser). The ray starts at the sighting position, so shots land
## exactly under the crosshair; the bolt is drawn from the muzzle.

const MAX_SHOTS_PER_FRAME: int = 4

var _cooldown_s: float = 0.0


func _update_weapon(delta_s: float) -> void:
	_cooldown_s -= delta_s
	if not (trigger_held and heat.can_fire() and has_ammo()):
		_cooldown_s = maxf(_cooldown_s, 0.0)
		return
	# Energy weapons keep their fire rate (scale 1); power changes their damage instead.
	var interval_s: float = 1.0 / (float(data.get("fire_rate", 1.0)) * get_rate_scale())
	var shots: int = 0
	while _cooldown_s <= 0.0 and shots < MAX_SHOTS_PER_FRAME and heat.can_fire() and has_ammo():
		# More power makes the bolt visibly brighter and thicker.
		var power: float = get_damage_scale()
		_hitscan_shot(_spread(_context.aim_direction, data.get("spread_deg", 0.0)), float(data.get("damage", 0.0)) * power,
			float(_visual("tracer_width_m", 0.1)) * (0.6 + 0.4 * power), 4.0 * power)
		_spend_ammo()
		_apply_shot_feedback()
		_cooldown_s += interval_s
		shots += 1
	_cooldown_s = maxf(_cooldown_s, 0.0)
