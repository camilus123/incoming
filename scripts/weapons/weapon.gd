class_name Weapon
extends Node3D
## Base class of all weapons. One script per archetype extends it.
##
## The base handles what every weapon shares: its data, heat, ammo, model,
## muzzle sockets and recoil. Archetypes implement `_update_weapon()`.
## A weapon is mounted as a child of a turret mount socket.

const NO_LOCKS: Array[CombatTarget] = []
const UNLIMITED_AMMO: int = -1

## The weapon's data file contents.
var data: Dictionary = {}
## "primary" or "alternate".
var slot: StringName = &""
var heat: HeatModel = HeatModel.new()
var trigger_held: bool = false
## Rounds left this stage, or UNLIMITED_AMMO.
var ammo: int = UNLIMITED_AMMO

var _context: WeaponContext
var _model: Node3D
var _muzzles: Array[Node3D] = []
var _next_muzzle: int = 0
var _kick_m: float = 0.0
var _kick_recover_per_s: float = 14.0
var _damage_info: DamageInfo = DamageInfo.new()
var _tracer_color: Color = Color.WHITE


## Prepares the weapon from its data. Called once before it enters the tree.
func setup(weapon_data: Dictionary, weapon_slot: StringName, context: WeaponContext) -> void:
	data = weapon_data
	slot = weapon_slot
	_context = context
	name = "Weapon_" + str(weapon_data.get("id", "unknown"))
	heat.configure(weapon_data.get("heat", {}))
	_damage_info.configure_from_weapon(weapon_data, weapon_slot)
	_kick_recover_per_s = _feel("recoil_recover_per_s", 14.0)
	var color: Array = _visual("tracer_color", [1.0, 1.0, 1.0])
	_tracer_color = Color(color[0], color[1], color[2])
	refill_ammo()
	_build_model()
	_setup_weapon()


## Refills the per-stage ammo stock (called between stages).
func refill_ammo() -> void:
	var per_stage: int = data.get("ammo_per_stage", 0)
	ammo = per_stage if per_stage > 0 else UNLIMITED_AMMO


func set_trigger(held: bool) -> void:
	trigger_held = held


func has_ammo() -> bool:
	return ammo == UNLIMITED_AMMO or ammo > 0


## 0 when ready, counting down from 1 while reloading. For the HUD.
func get_reload_fraction() -> float:
	return 0.0


## Targets currently locked by this weapon (homing weapons only).
func get_lock_targets() -> Array[CombatTarget]:
	return NO_LOCKS


## 0..1 progress towards the next lock (homing weapons only).
func get_lock_progress() -> float:
	return 0.0


func _process(delta_s: float) -> void:
	# Cooling scales with the power split only for weapons that use reactor power.
	var cooling_multiplier: float = _context.power_output if data.get("uses_power", true) else 1.0
	heat.tick(delta_s, cooling_multiplier)
	_update_weapon(delta_s)
	if _model != null and _kick_m > 0.0:
		_kick_m = lerpf(_kick_m, 0.0, 1.0 - exp(-_kick_recover_per_s * delta_s))
		_model.position.z = _kick_m


## Archetype hook: one-time preparation after the model exists.
func _setup_weapon() -> void:
	pass


## Archetype hook: called every frame to fire, lock, reload, ...
func _update_weapon(_delta_s: float) -> void:
	pass


## Returns the next muzzle index, cycling through all barrels.
func _take_muzzle() -> int:
	var index: int = _next_muzzle
	_next_muzzle = (_next_muzzle + 1) % _muzzles.size()
	return index


## World position where the given muzzle appears on screen.
func _muzzle_position(index: int) -> Vector3:
	return _context.rig.viewmodel_to_world(_muzzles[index].global_position)


## Shared shot feedback: heat, recoil kick, shake, stats event.
func _apply_shot_feedback() -> void:
	heat.add_shot()
	_kick_m = minf(_kick_m + _feel("recoil_kick_m", 0.0), 0.3)
	_context.rig.add_recoil(_feel("recoil_pitch_deg", 0.0))
	_context.rig.add_shake(_feel("shake", 0.0))
	EventBus.weapon_fired.emit(slot)
	if heat.overheated:
		EventBus.weapon_overheated.emit(slot)


func _feel(key: String, fallback: float) -> float:
	var feel: Dictionary = data.get("feel", {})
	return feel.get(key, fallback)


func _visual(key: String, fallback: Variant) -> Variant:
	var visuals: Dictionary = data.get("visuals", {})
	return visuals.get(key, fallback)


func _build_model() -> void:
	var scene: PackedScene = GameData.assets.load_asset(_visual("model", "")) as PackedScene
	_model = scene.instantiate() if scene != null else Node3D.new()
	add_child(_model)
	Layers.set_render_layers(_model, _context.rig.get_viewmodel_layers())
	var found: Array[Node] = _model.find_children("Muzzle_*", "Node3D", true, false)
	found.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	for node: Node in found:
		_muzzles.append(node as Node3D)
	if _muzzles.is_empty():
		# A model without sockets still works: fire from 1 m in front of the mount.
		var fallback: Node3D = Node3D.new()
		fallback.name = "Muzzle_0"
		fallback.position = Vector3(0.0, 0.0, -1.0)
		_model.add_child(fallback)
		_muzzles.append(fallback)
