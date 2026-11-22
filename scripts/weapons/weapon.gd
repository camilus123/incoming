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
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


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
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = Layers.PHYSICS_WORLD | Layers.PHYSICS_ENEMY | Layers.PHYSICS_ENEMY_PROJECTILE
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


## Damage multiplier from the power split. Energy weapons put reactor power
## into damage; everything else keeps its damage.
func get_damage_scale() -> float:
	if data.get("uses_power", true) and data.get("damage_type", "") == "energy":
		return _context.power_output
	return 1.0


## Fire rate and cooling multiplier from the power split. Powered weapons
## that are not energy weapons (kinetic) put reactor power into their rate.
func get_rate_scale() -> float:
	if data.get("uses_power", true) and data.get("damage_type", "") != "energy":
		return _context.power_output
	return 1.0


## 0 when ready, counting down from 1 while reloading. For the HUD.
func get_reload_fraction() -> float:
	return 0.0


## 0..1 charge of a hold-to-charge weapon (charge weapons only). For the HUD.
func get_charge_fraction() -> float:
	return 0.0


## Targets currently locked by this weapon (homing weapons only).
func get_lock_targets() -> Array[CombatTarget]:
	return NO_LOCKS


## 0..1 progress towards the next lock (homing weapons only).
func get_lock_progress() -> float:
	return 0.0


func _process(delta_s: float) -> void:
	heat.tick(delta_s, get_rate_scale())
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


func _spend_ammo(amount: int = 1) -> void:
	if ammo != UNLIMITED_AMMO:
		ammo = maxi(0, ammo - amount)


## The archetype's own block of the data file (e.g. "beam", "projectile").
func _block(block_name: String) -> Dictionary:
	return data.get(block_name, {})


## Casts the aim ray. Returns the physics hit ({} if nothing was hit).
## `exclude` lists colliders to ignore (used when piercing).
func _cast_aim_ray(direction: Vector3, exclude: Array[RID] = []) -> Dictionary:
	_ray.from = _context.aim_origin
	_ray.to = _context.aim_origin + direction * float(data.get("range_m", 5000.0))
	_ray.exclude = exclude
	return _context.world.direct_space_state.intersect_ray(_ray)


## One instant-hit shot along `direction`: damages what it hits and draws the
## tracer from the next muzzle. Returns the point where the shot ended.
func _hitscan_shot(direction: Vector3, damage: float, tracer_width_m: float, tracer_intensity: float = 4.0) -> Vector3:
	var end: Vector3 = _context.aim_origin + direction * float(data.get("range_m", 5000.0))
	var hit: Dictionary = _cast_aim_ray(direction)
	if not hit.is_empty():
		end = hit["position"]
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox != null:
			_damage_info.amount = damage
			_damage_info.hit_position = end
			hurtbox.redirect(_context.aim_origin, direction, _context.aim_origin.distance_to(end)).apply_hit(_damage_info)
	var muzzle: Vector3 = _muzzle_position(_take_muzzle())
	if _context.fx != null:
		_context.fx.tracer(muzzle, end, _tracer_color, tracer_width_m, _visual("tracer_life_s", 0.07), tracer_intensity)
		_context.fx.flash(muzzle, 0.05, 0.22, _tracer_color, 0.05, 6.0)
		if not hit.is_empty():
			_context.fx.flash(end, 0.3, _visual("impact_radius_m", 2.0), _tracer_color, 0.12, 5.0)
	return end


## Direction from a muzzle to the point the crosshair is on, so projectiles
## launched from the barrel still go where the player aims.
func _aim_direction_from(muzzle: Vector3) -> Vector3:
	var range_m: float = data.get("range_m", 5000.0)
	var aim_point: Vector3 = _context.aim_origin + _context.aim_direction * minf(range_m, 1500.0)
	var hit: Dictionary = _cast_aim_ray(_context.aim_direction)
	if not hit.is_empty():
		aim_point = hit["position"]
	return (aim_point - muzzle).normalized()


## Returns `direction` deflected by a random angle of up to `spread_deg`.
func _spread(direction: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var deflected: Vector3 = direction.rotated(side, deg_to_rad(randf() * spread_deg))
	return deflected.rotated(direction, randf() * TAU)

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
