class_name Turret
extends Node3D
## The player's turret: aim, hull, weapon slots and the camera rig.
##
## Input moves the aim ([TurretAim]) directly. Every frame the turret hands
## the exact aim transform to the camera rig and the weapons, while the
## visible mechanics (yaw ring, gun cradle) follow with a small smoothing.

const GROUP: StringName = &"player_turret"
const SLOT_PRIMARY: StringName = &"primary"
const SLOT_ALTERNATE: StringName = &"alternate"
const SLOTS: Array[StringName] = [SLOT_PRIMARY, SLOT_ALTERNATE]
const FIRE_ACTIONS: Dictionary = {SLOT_PRIMARY: &"fire_primary", SLOT_ALTERNATE: &"fire_alternate"}
const MOUNT_SOCKETS: Dictionary = {SLOT_PRIMARY: "Mount_Primary", SLOT_ALTERNATE: "Mount_Alternate"}

const ACTION_POWER_TO_WEAPONS: StringName = &"power_to_weapons"
const ACTION_POWER_TO_SHIELDS: StringName = &"power_to_shields"
const ACTION_POWER_RESET: StringName = &"power_reset"

var aim: TurretAim = TurretAim.new()
var power: PowerSystem = PowerSystem.new()
var shield: ShieldState = ShieldState.new()
var rig: CameraRig
var hull: float = 0.0
var max_hull: float = 0.0
## Set to false to drive the turret from code (automated demo, cutscenes).
var player_input_enabled: bool = true
## Debug: the turret takes no damage.
var invulnerable: bool = false
var destroyed: bool = false

var _config: Dictionary = {}
var _context: WeaponContext = WeaponContext.new()
var _weapons: Dictionary = {}       # slot -> Weapon
var _equipped_ids: Dictionary = {}  # slot -> weapon id
var _triggers: Dictionary = {SLOT_PRIMARY: false, SLOT_ALTERNATE: false}
var _mounts: Dictionary = {}        # slot -> Node3D
var _model: Node3D
var _pivot_yaw: Node3D
var _pivot_pitch: Node3D
var _pivot_yaw_rest: Transform3D
var _pivot_pitch_rest: Transform3D
# Rest transforms of the aim chain, used to compute the exact aim transform.
var _yaw_in_turret: Transform3D
var _pitch_in_yaw: Transform3D
var _anchor_in_pitch: Transform3D
var _degrees_per_count: float = 0.04
var _smoothing_default_s: float = 0.03
var _dome: ShieldDome
var _shield_id: String = ""


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_config = GameData.loader.get_config("turret")
	_read_config()
	max_hull = _block("hull").get("max", 200.0)
	hull = max_hull

	rig = FirstPersonRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.configure(_block("camera"))

	_build_model()
	_context.rig = rig
	_context.world = get_world_3d()
	_context.fx = get_tree().get_first_node_in_group(CombatFx.GROUP) as CombatFx
	_context.missiles = get_tree().get_first_node_in_group(MissileSystem.GROUP) as MissileSystem

	_dome = ShieldDome.new()
	_dome.name = "ShieldDome"
	add_child(_dome)
	power.configure(GameData.loader.get_config("power"))
	var loadout: Dictionary = _block("default_loadout")
	equip_shield(loadout.get("shield", ""))
	for slot: StringName in SLOTS:
		equip(slot, loadout.get(String(slot), ""))
	EventBus.data_reloaded.connect(_on_data_reloaded)
	_update_aim_outputs(0.0)


## Puts the weapon with the given data id into a slot. Returns false if the
## weapon is unknown, not allowed in that slot, or its archetype is missing.
func equip(slot: StringName, weapon_id: String) -> bool:
	var weapon_data: Dictionary = GameData.loader.get_entry("weapons", weapon_id)
	if weapon_data.is_empty():
		push_warning("Turret: unknown weapon \"%s\" for slot %s" % [weapon_id, slot])
		return false
	if not (weapon_data["allowed_slots"] as Array).has(String(slot)):
		push_warning("Turret: weapon \"%s\" is not allowed in slot %s" % [weapon_id, slot])
		return false
	var weapon: Weapon = WeaponFactory.create(weapon_data)
	if weapon == null:
		return false
	if _weapons.has(slot):
		(_weapons[slot] as Weapon).queue_free()
	weapon.setup(weapon_data, slot, _context)
	(_mounts[slot] as Node3D).add_child(weapon)
	_weapons[slot] = weapon
	_equipped_ids[slot] = weapon_id
	return true


## Installs the shield with the given data id (fully charged).
func equip_shield(shield_id: String) -> bool:
	var shield_data: Dictionary = GameData.loader.get_entry("shields", shield_id)
	if shield_data.is_empty():
		push_warning("Turret: unknown shield \"%s\"" % shield_id)
		return false
	_shield_id = shield_id
	shield.configure(shield_data)
	_dome.configure(shield_data.get("visuals", {}))
	return true


## Moves the power split one step: +1 towards weapons, -1 towards shields,
## 0 resets it. Returns true if it changed.
func shift_power(direction: int) -> bool:
	var changed: bool = false
	if direction > 0:
		changed = power.shift_to_weapons()
	elif direction < 0:
		changed = power.shift_to_shields()
	else:
		changed = power.reset()
	if changed:
		EventBus.power_split_changed.emit(power.shield_share)
	return changed


## The point enemies fly at and shoot at (roughly the gun cradle).
func get_hit_point() -> Vector3:
	return global_transform * _yaw_in_turret.origin + Vector3.UP * 0.8


## Damages the turret. The shield absorbs what it can; the rest hits the hull.
## `from_position` is where the hit came from (for the shield ripple).
func take_damage(amount: float, from_position: Vector3 = Vector3.INF) -> void:
	if destroyed or invulnerable or amount <= 0.0:
		return
	var through: float = amount
	if shield.is_up():
		through = shield.absorb(amount)
		_dome.add_impact(from_position if from_position.is_finite() else get_hit_point() + Vector3.UP)
		rig.add_shake(clampf(amount / 120.0, 0.05, 0.3))
		EventBus.shield_hit.emit(amount - through, shield.charge)
		if not shield.is_up():
			_dome.flash(1.0)
			EventBus.shield_broken.emit()
	if through <= 0.0:
		return
	hull = maxf(0.0, hull - through)
	rig.add_shake(clampf(through / 40.0, 0.15, 0.8))
	EventBus.hull_damaged.emit(through, hull)
	if hull <= 0.0:
		destroyed = true
		EventBus.turret_destroyed.emit()


## Repairs the hull and refills ammo for a new stage. Temporary until the
## shop (M4) sells repairs.
func restore_for_stage() -> void:
	destroyed = false
	hull = max_hull
	shield.refill()
	for slot: StringName in SLOTS:
		var weapon: Weapon = _weapons.get(slot)
		if weapon != null:
			weapon.refill_ammo()
			weapon.heat.heat = 0.0
			weapon.heat.overheated = false


## The weapon in a slot, or null.
func get_weapon(slot: StringName) -> Weapon:
	return _weapons.get(slot)


## Presses or releases a trigger from code (used when player input is off).
func set_trigger(slot: StringName, held: bool) -> void:
	_triggers[slot] = held


## Exact, unsmoothed transform of the sighting position for the current aim.
func get_aim_transform() -> Transform3D:
	var yaw: Transform3D = Transform3D(Basis(Vector3.UP, -deg_to_rad(aim.yaw_deg)), Vector3.ZERO)
	var pitch: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(aim.pitch_deg)), Vector3.ZERO)
	return global_transform * _yaw_in_turret * yaw * _pitch_in_yaw * pitch * _anchor_in_pitch


## Yaw and pitch (degrees) needed to aim at a world position.
func get_aim_angles_to(world_position: Vector3) -> Vector2:
	var origin: Vector3 = get_aim_transform().origin
	return TurretAim.angles_to(global_transform.basis.inverse() * (world_position - origin))


func _input(event: InputEvent) -> void:
	if not player_input_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	# screen_relative is in real mouse counts, unaffected by UI scaling.
	var sensitivity: float = _degrees_per_count * float(UserSettings.get_value(UserSettings.MOUSE_SENSITIVITY))
	var pitch_scale: float = float(UserSettings.get_value(UserSettings.MOUSE_SENSITIVITY_Y_SCALE))
	if UserSettings.get_value(UserSettings.INVERT_Y):
		pitch_scale = -pitch_scale
	aim.apply_input(motion.screen_relative.x * sensitivity, -motion.screen_relative.y * sensitivity * pitch_scale)


func _unhandled_input(event: InputEvent) -> void:
	if not player_input_enabled or destroyed or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed(ACTION_POWER_TO_WEAPONS):
		shift_power(1)
	elif event.is_action_pressed(ACTION_POWER_TO_SHIELDS):
		shift_power(-1)
	elif event.is_action_pressed(ACTION_POWER_RESET):
		shift_power(0)


func _process(delta_s: float) -> void:
	_context.power_output = power.weapon_output_multiplier()
	if not destroyed and shield.tick(delta_s, power.shield_recharge_multiplier()) > 0:
		_dome.flash(0.6)
		EventBus.shield_restored.emit()
	_dome.set_charge(shield.get_fraction())
	if player_input_enabled:
		var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		for slot: StringName in SLOTS:
			_triggers[slot] = captured and Input.is_action_pressed(FIRE_ACTIONS[slot])
	for slot: StringName in SLOTS:
		var weapon: Weapon = _weapons.get(slot)
		if weapon != null:
			weapon.set_trigger(_triggers[slot] and not destroyed)
	_update_aim_outputs(delta_s)


## Pushes the current aim to the camera, the weapons and the visible model.
func _update_aim_outputs(delta_s: float) -> void:
	var aim_transform: Transform3D = get_aim_transform()
	_context.aim_origin = aim_transform.origin
	_context.aim_direction = -aim_transform.basis.z
	rig.update_rig(aim_transform, delta_s)

	aim.update_visual(delta_s, UserSettings.get_float_or(UserSettings.TURRET_SMOOTHING_S, _smoothing_default_s))
	_pivot_yaw.transform = _pivot_yaw_rest * Transform3D(Basis(Vector3.UP, -deg_to_rad(aim.visual_yaw_deg)), Vector3.ZERO)
	_pivot_pitch.transform = _pivot_pitch_rest * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(aim.visual_pitch_deg)), Vector3.ZERO)


func _read_config() -> void:
	var aim_config: Dictionary = _block("aim")
	aim.configure(aim_config)
	_degrees_per_count = aim_config.get("degrees_per_mouse_count", 0.04)
	_smoothing_default_s = aim_config.get("smoothing_default_s", 0.03)


func _block(key: String) -> Dictionary:
	return _config.get(key, {})


func _build_model() -> void:
	var scene: PackedScene = GameData.assets.load_asset(_config.get("model", "")) as PackedScene
	_model = scene.instantiate() if scene != null else Node3D.new()
	_model.name = "Model"
	add_child(_model)

	# Missing sockets get sensible defaults so a broken model never stops the game.
	_pivot_yaw = _socket("Pivot_Yaw", _model, Vector3(0.0, 0.7, 0.0))
	_pivot_pitch = _socket("Pivot_Pitch", _pivot_yaw, Vector3(0.0, 1.3, 0.0))
	var anchor: Node3D = _socket("ViewAnchor", _pivot_pitch, Vector3(0.0, 0.35, 0.4))
	_mounts[SLOT_PRIMARY] = _socket(MOUNT_SOCKETS[SLOT_PRIMARY], _pivot_pitch, Vector3(0.0, -0.4, -0.6))
	_mounts[SLOT_ALTERNATE] = _socket(MOUNT_SOCKETS[SLOT_ALTERNATE], _pivot_pitch, Vector3(1.5, -0.35, -1.0))

	_pivot_yaw_rest = _pivot_yaw.transform
	_pivot_pitch_rest = _pivot_pitch.transform
	_yaw_in_turret = global_transform.affine_inverse() * _pivot_yaw.global_transform
	_pitch_in_yaw = _pivot_yaw.global_transform.affine_inverse() * _pivot_pitch.global_transform
	_anchor_in_pitch = _pivot_pitch.global_transform.affine_inverse() * anchor.global_transform
	Layers.set_render_layers(_model, rig.get_viewmodel_layers())


func _socket(socket_name: String, default_parent: Node3D, default_position: Vector3) -> Node3D:
	var found: Node3D = _model.find_child(socket_name, true, false) as Node3D
	if found != null:
		return found
	push_warning("Turret model has no socket \"%s\"; using a default position" % socket_name)
	var socket: Node3D = Node3D.new()
	socket.name = socket_name
	socket.position = default_position
	default_parent.add_child(socket)
	return socket


func _on_data_reloaded(_report: DataReport) -> void:
	# Hot reload: pick up new limits and rebuild the weapons from the new data.
	_config = GameData.loader.get_config("turret")
	_read_config()
	rig.configure(_block("camera"))
	power.configure(GameData.loader.get_config("power"), false)
	if not _shield_id.is_empty():
		var charge_fraction: float = shield.get_fraction()
		equip_shield(_shield_id)
		shield.charge = shield.capacity * charge_fraction
	for slot: StringName in SLOTS:
		if _equipped_ids.has(slot):
			equip(slot, _equipped_ids[slot])
