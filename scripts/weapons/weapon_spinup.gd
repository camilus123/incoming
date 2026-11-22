extends Weapon
## Archetype "spinup": instant-hit rounds whose fire rate ramps up while the
## trigger is held and winds down when it is released (Chain Gun).
## Data block "spinup": fire_rate_min, spinup_s, spindown_s. The top rate is
## the weapon's `fire_rate`. A model node named "Spin_0" rotates with the barrels.

const MAX_SHOTS_PER_FRAME: int = 6
const SPIN_TURNS_PER_S: float = 9.0

var _spin: float = 0.0  # 0 = stopped, 1 = full speed
var _cooldown_s: float = 0.0
var _spinner: Node3D


func _setup_weapon() -> void:
	_spinner = _model.find_child("Spin_0", true, false) as Node3D


## 0..1, how far the barrels have spun up (shown on the HUD as charge).
func get_charge_fraction() -> float:
	return _spin


func _update_weapon(delta_s: float) -> void:
	var block: Dictionary = _block("spinup")
	var firing: bool = trigger_held and heat.can_fire() and has_ammo()
	if firing:
		_spin = minf(1.0, _spin + delta_s / maxf(float(block.get("spinup_s", 1.2)), 0.01))
	else:
		_spin = maxf(0.0, _spin - delta_s / maxf(float(block.get("spindown_s", 0.8)), 0.01))
	if _spinner != null and _spin > 0.0:
		_spinner.rotate_z(_spin * SPIN_TURNS_PER_S * TAU * delta_s)

	_cooldown_s -= delta_s
	if not firing:
		_cooldown_s = maxf(_cooldown_s, 0.0)
		return
	# Kinetic weapons put reactor power into their rate of fire.
	var rate: float = lerpf(float(block.get("fire_rate_min", 6.0)), float(data.get("fire_rate", 30.0)), _spin) * get_rate_scale()
	var shots: int = 0
	while _cooldown_s <= 0.0 and shots < MAX_SHOTS_PER_FRAME and heat.can_fire() and has_ammo():
		_hitscan_shot(_spread(_context.aim_direction, data.get("spread_deg", 0.0)), float(data.get("damage", 0.0)) * get_damage_scale(),
			_visual("tracer_width_m", 0.06), 3.0)
		_spend_ammo()
		_apply_shot_feedback()
		_cooldown_s += 1.0 / maxf(rate, 0.1)
		shots += 1
	_cooldown_s = maxf(_cooldown_s, 0.0)
