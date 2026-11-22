class_name MissileSystem
extends Node3D
## Simulates and draws all player homing missiles from a fixed pool.
##
## Missiles are not physics bodies. Each frame a missile steers towards its
## target (leading it), then sweeps a ray along the distance it travels, so
## fast missiles cannot tunnel through targets. Detonation deals splash damage
## to every target in range.

const GROUP: StringName = &"missile_system"
const POOL_SIZE: int = 64


class Missile:
	var active: bool = false
	var position: Vector3
	var direction: Vector3
	var speed: float
	var age_s: float
	var target: CombatTarget
	var weapon_data: Dictionary
	var homing: Dictionary
	var info: DamageInfo = DamageInfo.new()
	var visual: Node3D
	var visual_id: String = ""
	var trail: GPUParticles3D
	## Player-steered missiles fly towards this point instead of a target.
	var steered: bool = false
	var steer_point: Vector3
	var flare_checked: bool = false


var _missiles: Array[Missile] = []
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _trail_material: ParticleProcessMaterial
var _trail_mesh: QuadMesh
var _pool_warning_shown: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = Layers.PHYSICS_WORLD | Layers.PHYSICS_ENEMY | Layers.PHYSICS_ENEMY_PROJECTILE
	_build_trail_resources()
	for index: int in POOL_SIZE:
		_missiles.append(Missile.new())


## Launches one missile from `origin` along `direction`. `target` may be null
## for an unguided shot. `weapon_data` is the weapon's data file.
## Returns a handle for `steer()`, or -1 if the pool is full.
func launch(origin: Vector3, direction: Vector3, target: CombatTarget, weapon_data: Dictionary, slot: StringName) -> int:
	var missile: Missile = _take_free()
	if missile == null:
		return -1
	missile.steered = false
	missile.flare_checked = false
	missile.active = true
	missile.position = origin
	missile.direction = direction.normalized()
	missile.homing = weapon_data.get("homing", {})
	missile.speed = missile.homing.get("launch_speed_mps", 60.0)
	missile.age_s = 0.0
	missile.target = target
	missile.weapon_data = weapon_data
	missile.info.configure_from_weapon(weapon_data, slot)
	_prepare_visual(missile)
	_place_visual(missile)
	missile.visual.visible = true
	missile.trail.restart()
	missile.trail.emitting = true
	return _missiles.find(missile)


## Steers a player-guided missile (Seeker Torpedo) towards a point. Call it
## every frame while the player is steering; without calls the missile flies straight.
func steer(handle: int, point: Vector3) -> void:
	if handle >= 0 and handle < _missiles.size() and _missiles[handle].active:
		_missiles[handle].steered = true
		_missiles[handle].steer_point = point


## Gives a flying missile a (new) target to home on; null makes it fly straight.
func set_target(handle: int, target: CombatTarget) -> void:
	if handle >= 0 and handle < _missiles.size() and _missiles[handle].active:
		_missiles[handle].target = target


## True while the missile with this handle is still flying.
func is_flying(handle: int) -> bool:
	return handle >= 0 and handle < _missiles.size() and _missiles[handle].active


## World position of a flying missile.
func get_missile_position(handle: int) -> Vector3:
	return _missiles[handle].position if is_flying(handle) else Vector3.ZERO


## Number of missiles in flight (for the debug overlay and tests).
func get_active_count() -> int:
	var count: int = 0
	for missile: Missile in _missiles:
		if missile.active:
			count += 1
	return count


func _process(delta_s: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for missile: Missile in _missiles:
		if missile.active:
			_update_missile(missile, delta_s, space)


func _update_missile(missile: Missile, delta_s: float, space: PhysicsDirectSpaceState3D) -> void:
	var homing: Dictionary = missile.homing
	missile.age_s += delta_s
	missile.speed = minf(missile.speed + float(homing.get("acceleration_mps2", 400.0)) * delta_s, homing.get("speed_mps", 300.0))

	var has_target: bool = is_instance_valid(missile.target) and missile.target.is_alive()
	if not has_target:
		# Forget it for good: a pooled enemy comes back to life as a different enemy.
		missile.target = null
	var armed: bool = missile.age_s >= float(homing.get("arm_delay_s", 0.15))
	if has_target and armed and not missile.flare_checked:
		# Some enemies drop flares: the missile may lose its lock once.
		missile.flare_checked = true
		var enemy: Enemy = missile.target as Enemy
		if enemy != null and enemy.try_flare():
			missile.target = null
			has_target = false
	if missile.steered:
		_turn_towards(missile, (missile.steer_point - missile.position).normalized(), delta_s)
		missile.steered = false
	elif has_target and armed:
		_steer(missile, delta_s)

	var next_position: Vector3 = missile.position + missile.direction * missile.speed * delta_s
	_ray.from = missile.position
	_ray.to = next_position
	var hit: Dictionary = space.intersect_ray(_ray)
	if not hit.is_empty():
		_detonate(missile, hit["position"])
		return
	missile.position = next_position

	if has_target:
		var fuse_m: float = float(homing.get("proximity_fuse_m", 3.0)) + missile.target.target_radius_m
		if missile.position.distance_squared_to(missile.target.get_aim_point()) <= fuse_m * fuse_m:
			_detonate(missile, missile.position)
			return
	if missile.age_s >= float(homing.get("lifetime_s", 14.0)):
		_detonate(missile, missile.position)
		return
	_place_visual(missile)


## Turns the missile towards the point where it will meet its target.
func _steer(missile: Missile, delta_s: float) -> void:
	var aim_point: Vector3 = missile.target.get_aim_point()
	var distance: float = missile.position.distance_to(aim_point)
	var lead_s: float = distance / maxf(missile.speed, 1.0)
	_turn_towards(missile, (aim_point + missile.target.velocity * lead_s - missile.position).normalized(), delta_s)


## Rotates the missile's flight direction towards `desired`, limited by its turn rate.
func _turn_towards(missile: Missile, desired: Vector3, delta_s: float) -> void:
	var angle: float = missile.direction.angle_to(desired)
	if angle < 0.0005:
		missile.direction = desired
		return
	var axis: Vector3 = missile.direction.cross(desired)
	if axis.length_squared() < 0.000001:
		axis = missile.direction.cross(Vector3.UP)
	var max_turn: float = deg_to_rad(missile.homing.get("turn_rate_deg_s", 110.0)) * delta_s
	missile.direction = missile.direction.rotated(axis.normalized(), minf(angle, max_turn)).normalized()


func _detonate(missile: Missile, at: Vector3) -> void:
	missile.active = false
	missile.visual.visible = false
	missile.trail.emitting = false

	var radius_m: float = missile.homing.get("splash_radius_m", 8.0)
	Splash.apply(get_tree(), at, radius_m, missile.weapon_data.get("damage", 0.0), missile.info)

	var fx: CombatFx = get_tree().get_first_node_in_group(CombatFx.GROUP) as CombatFx
	if fx != null:
		var visuals: Dictionary = missile.weapon_data.get("visuals", {})
		fx.explosion(at, visuals.get("impact_radius_m", radius_m), Color(1.0, 0.6, 0.25))
	missile.target = null


func _take_free() -> Missile:
	for missile: Missile in _missiles:
		if not missile.active:
			return missile
	if not _pool_warning_shown:
		_pool_warning_shown = true
		push_warning("MissileSystem: pool of %d missiles is exhausted; extra launches are dropped" % POOL_SIZE)
	return null


func _prepare_visual(missile: Missile) -> void:
	var visuals: Dictionary = missile.weapon_data.get("visuals", {})
	var model_id: String = visuals.get("projectile_model", "")
	if missile.visual != null and missile.visual_id == model_id:
		return
	if missile.visual != null:
		missile.visual.queue_free()
	var scene: PackedScene = GameData.assets.load_asset(model_id) as PackedScene if not model_id.is_empty() else null
	missile.visual = scene.instantiate() if scene != null else _fallback_visual()
	missile.visual_id = model_id
	add_child(missile.visual)

	missile.trail = GPUParticles3D.new()
	missile.trail.amount = 48
	missile.trail.lifetime = 0.7
	missile.trail.local_coords = false
	missile.trail.emitting = false
	missile.trail.process_material = _trail_material
	missile.trail.draw_pass_1 = _trail_mesh
	missile.trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	missile.trail.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var engine: Node3D = missile.visual.find_child("Engine_0", true, false) as Node3D
	(engine if engine != null else missile.visual).add_child(missile.trail)


func _place_visual(missile: Missile) -> void:
	var up: Vector3 = Vector3.UP if absf(missile.direction.y) < 0.99 else Vector3.RIGHT
	missile.visual.global_transform = Transform3D(Basis.looking_at(missile.direction, up), missile.position)


func _fallback_visual() -> Node3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.6)
	instance.mesh = mesh
	return instance


func _build_trail_resources() -> void:
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.4, 0.6))
	fade.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var fade_texture: GradientTexture1D = GradientTexture1D.new()
	fade_texture.gradient = fade

	_trail_material = ParticleProcessMaterial.new()
	_trail_material.gravity = Vector3.ZERO
	_trail_material.spread = 180.0
	_trail_material.initial_velocity_min = 0.2
	_trail_material.initial_velocity_max = 1.0
	_trail_material.scale_min = 0.6
	_trail_material.scale_max = 1.2
	_trail_material.color_ramp = fade_texture

	var soft: Gradient = Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var puff: GradientTexture2D = GradientTexture2D.new()
	puff.gradient = soft
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 64
	puff.height = 64

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = puff
	material.albedo_color = Color(0.7, 0.7, 0.7)
	_trail_mesh = QuadMesh.new()
	_trail_mesh.size = Vector2(0.7, 0.7)
	_trail_mesh.material = material
