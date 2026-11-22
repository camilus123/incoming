class_name ProjectileSystem
extends Node3D
## Simulates and draws all unguided player projectiles from a fixed pool:
## plasma bolts, coilgun slugs, flak shells, EMP shells, singularity charges.
## It also runs the lingering effects some of them leave behind (the Hyper-Rail
## trail, the gravity well).
##
## Projectiles are not physics bodies. Each frame a projectile moves, then a
## ray is swept along the distance travelled, so fast shots cannot tunnel
## through targets. Behaviour comes from the weapon's "projectile" data block.

const GROUP: StringName = &"projectile_system"
const POOL_SIZE: int = 160
const ZONE_TICK_S: float = 0.25
const SHADER_ASSET: String = "vfx.shader.glow_unlit"


class Shot:
	var active: bool = false
	var position: Vector3
	var velocity: Vector3
	var age_s: float
	var block: Dictionary
	var weapon_data: Dictionary
	var mode: String
	var damage: float
	var pierce_left: int
	var info: DamageInfo = DamageInfo.new()
	var exclude: Array[RID] = []
	var visual: MeshInstance3D
	var color: Color


## A lingering damage area: a line (Hyper-Rail trail) or a gravity well.
class Zone:
	var kind: String
	var from: Vector3
	var to: Vector3
	var radius_m: float
	var dps: float
	var time_left_s: float
	var tick_s: float = 0.0
	var settings: Dictionary = {}
	var info: DamageInfo = DamageInfo.new()
	var visual: MeshInstance3D


var _shots: Array[Shot] = []
var _zones: Array[Zone] = []
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _fx: CombatFx
var _well_mesh: SphereMesh
var _pool_warning_shown: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = Layers.PHYSICS_WORLD | Layers.PHYSICS_ENEMY | Layers.PHYSICS_ENEMY_PROJECTILE
	_fx = get_tree().get_first_node_in_group(CombatFx.GROUP) as CombatFx

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader
	var bolt: BoxMesh = BoxMesh.new()
	bolt.size = Vector3.ONE
	bolt.material = material
	_well_mesh = SphereMesh.new()
	_well_mesh.radius = 1.0
	_well_mesh.height = 2.0
	_well_mesh.material = material
	for index: int in POOL_SIZE:
		var shot: Shot = Shot.new()
		shot.visual = MeshInstance3D.new()
		shot.visual.mesh = bolt
		shot.visual.visible = false
		shot.visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shot.visual)
		_shots.append(shot)


## Launches one projectile. `mode` selects what happens when it detonates:
## "" (plain hit or explosion), "emp" or "singularity".
func fire(origin: Vector3, direction: Vector3, weapon_data: Dictionary, slot: StringName, damage: float, mode: String = "") -> void:
	var shot: Shot = _take_free()
	if shot == null:
		return
	var block: Dictionary = weapon_data.get("projectile", {})
	shot.active = true
	shot.position = origin
	shot.velocity = direction.normalized() * float(block.get("speed_mps", 300.0))
	shot.age_s = 0.0
	shot.block = block
	shot.weapon_data = weapon_data
	shot.mode = mode
	shot.damage = damage
	shot.pierce_left = int(block.get("pierce", 0))
	shot.exclude.clear()
	shot.info.configure_from_weapon(weapon_data, slot)
	var visuals: Dictionary = weapon_data.get("visuals", {})
	var color: Array = visuals.get("tracer_color", [1.0, 1.0, 1.0])
	shot.color = Color(color[0], color[1], color[2])
	shot.visual.set_instance_shader_parameter(&"tint", shot.color)
	shot.visual.set_instance_shader_parameter(&"intensity", 5.0)
	_place_visual(shot)
	shot.visual.visible = true


## Starts a line of lingering damage (Hyper-Rail trail). `settings` has
## `duration_s`, `dps` and `radius_m`.
func add_trail(from: Vector3, to: Vector3, settings: Dictionary, weapon_data: Dictionary, slot: StringName, color: Color) -> void:
	var zone: Zone = Zone.new()
	zone.kind = "trail"
	zone.from = from
	zone.to = to
	zone.radius_m = settings.get("radius_m", 6.0)
	zone.dps = settings.get("dps", 50.0)
	zone.time_left_s = settings.get("duration_s", 3.0)
	zone.info.configure_from_weapon(weapon_data, slot)
	_zones.append(zone)
	if _fx != null:
		_fx.tracer(from, to, color, zone.radius_m * 0.25, zone.time_left_s, 2.0)


## Number of projectiles in flight (for the debug overlay and tests).
func get_active_count() -> int:
	var count: int = 0
	for shot: Shot in _shots:
		if shot.active:
			count += 1
	return count


func _process(delta_s: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for shot: Shot in _shots:
		if shot.active:
			_update_shot(shot, delta_s, space)
	for index: int in range(_zones.size() - 1, -1, -1):
		if not _update_zone(_zones[index], delta_s):
			if _zones[index].visual != null:
				_zones[index].visual.queue_free()
			_zones.remove_at(index)


func _update_shot(shot: Shot, delta_s: float, space: PhysicsDirectSpaceState3D) -> void:
	var block: Dictionary = shot.block
	shot.age_s += delta_s
	shot.velocity.y -= float(block.get("gravity_mps2", 0.0)) * delta_s
	var drag: float = block.get("drag", 0.0)
	if drag > 0.0:
		shot.velocity *= maxf(0.0, 1.0 - drag * delta_s)

	var next_position: Vector3 = shot.position + shot.velocity * delta_s
	_ray.from = shot.position
	_ray.to = next_position
	_ray.exclude = shot.exclude
	var hit: Dictionary = space.intersect_ray(_ray)
	if not hit.is_empty():
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox != null and shot.pierce_left > 0 and float(block.get("splash_radius_m", 0.0)) <= 0.0:
			# Piercing slug: damage this target and keep flying.
			shot.info.amount = shot.damage
			shot.info.hit_position = hit["position"]
			hurtbox.redirect(shot.position, shot.velocity.normalized(), shot.position.distance_to(hit["position"])).apply_hit(shot.info)
			shot.exclude.append(hit["rid"])
			shot.pierce_left -= 1
			if _fx != null:
				_fx.flash(hit["position"], 0.3, 2.0, shot.color, 0.12, 5.0)
		else:
			_detonate(shot, hit["position"], hurtbox)
			return
	shot.position = next_position

	# Proximity fuse (flak): burst as soon as any target is close enough.
	var fuse_m: float = block.get("proximity_fuse_m", 0.0)
	if fuse_m > 0.0 and shot.age_s > 0.05 and _target_within(shot.position, fuse_m):
		_detonate(shot, shot.position, null)
		return
	if shot.age_s >= float(block.get("lifetime_s", 4.0)):
		# Shells with a blast burst at the end of their range; slugs just vanish.
		if float(block.get("splash_radius_m", 0.0)) > 0.0 or not shot.mode.is_empty():
			_detonate(shot, shot.position, null)
		else:
			_retire(shot)
		return
	_place_visual(shot)


func _detonate(shot: Shot, at: Vector3, direct_hit: Hurtbox) -> void:
	var splash_m: float = shot.block.get("splash_radius_m", 0.0)
	match shot.mode:
		"emp":
			_emp_pulse(at, shot)
		"singularity":
			_start_well(at, shot)
		_:
			if splash_m > 0.0:
				Splash.apply(get_tree(), at, splash_m, shot.damage, shot.info)
				if _fx != null:
					_fx.explosion(at, splash_m, shot.color)
			else:
				if direct_hit != null:
					shot.info.amount = shot.damage
					shot.info.hit_position = at
					direct_hit.redirect(shot.position, shot.velocity.normalized(), shot.position.distance_to(at)).apply_hit(shot.info)
				if _fx != null:
					_fx.flash(at, 0.3, 2.5, shot.color, 0.12, 5.0)
	_retire(shot)


func _retire(shot: Shot) -> void:
	shot.active = false
	shot.visual.visible = false


## EMP: strips enemy shields and stuns tagged enemies around the impact.
func _emp_pulse(at: Vector3, shot: Shot) -> void:
	var settings: Dictionary = shot.weapon_data.get("area_pulse", {})
	var radius_m: float = settings.get("radius_m", 100.0)
	var stun_tags: Array = settings.get("stun_tags", [])
	var enemies: EnemyManager = get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	if enemies != null:
		for enemy: Enemy in enemies.get_enemies().duplicate():
			if not enemy.is_alive() or enemy.global_position.distance_to(at) - enemy.target_radius_m > radius_m:
				continue
			if settings.get("strip_shields", true):
				enemy.stats.shield = 0.0
				enemy.stats.note_hit()
			for tag: Variant in stun_tags:
				if enemy.has_tag(str(tag)):
					enemy.stagger(settings.get("stun_s", 3.0))
					break
			if shot.damage > 0.0:
				shot.info.amount = shot.damage
				shot.info.hit_position = at
				enemy.apply_damage(shot.info)
	if _fx != null:
		_fx.flash(at, radius_m * 0.1, radius_m, shot.color, 0.5, 2.5)


## Gravity well: pulls enemies in for a while, then implodes.
func _start_well(at: Vector3, shot: Shot) -> void:
	var settings: Dictionary = shot.weapon_data.get("singularity", {})
	var zone: Zone = Zone.new()
	zone.kind = "well"
	zone.from = at
	zone.radius_m = settings.get("pull_radius_m", 180.0)
	zone.time_left_s = settings.get("duration_s", 4.0)
	zone.settings = settings
	zone.dps = 0.0
	zone.info.configure_from_weapon(shot.weapon_data, shot.info.source_slot)
	zone.info.amount = shot.damage
	zone.visual = MeshInstance3D.new()
	zone.visual.mesh = _well_mesh
	zone.visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(zone.visual)
	zone.visual.global_position = at
	zone.visual.set_instance_shader_parameter(&"tint", shot.color)
	zone.visual.set_instance_shader_parameter(&"intensity", 3.0)
	_zones.append(zone)


## Advances a zone. Returns false when it has ended.
func _update_zone(zone: Zone, delta_s: float) -> bool:
	zone.time_left_s -= delta_s
	if zone.kind == "well":
		return _update_well(zone, delta_s)
	zone.tick_s += delta_s
	if zone.tick_s >= ZONE_TICK_S:
		zone.tick_s -= ZONE_TICK_S
		zone.info.amount = zone.dps * ZONE_TICK_S
		zone.info.armour_factor = ZONE_TICK_S
		for node: Node in get_tree().get_nodes_in_group(CombatTarget.GROUP):
			var target: CombatTarget = node as CombatTarget
			if target == null or not target.is_alive():
				continue
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(target.get_aim_point(), zone.from, zone.to)
			if closest.distance_to(target.get_aim_point()) <= zone.radius_m + target.target_radius_m:
				zone.info.hit_position = closest
				target.apply_damage(zone.info)
	return zone.time_left_s > 0.0


func _update_well(zone: Zone, delta_s: float) -> bool:
	var settings: Dictionary = zone.settings
	var enemies: EnemyManager = get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	var pull_mps: float = settings.get("pull_speed_mps", 40.0)
	var max_pull_hp: float = settings.get("max_pull_hp", 1000.0)
	if enemies != null:
		for enemy: Enemy in enemies.get_enemies():
			# Big ships are too heavy to move.
			if not enemy.is_alive() or enemy.stats.max_hp > max_pull_hp:
				continue
			var to_centre: Vector3 = zone.from - enemy.global_position
			var distance: float = to_centre.length()
			if distance <= zone.radius_m and distance > 1.0:
				enemy.global_position += to_centre / distance * minf(pull_mps * delta_s, distance)
	# The well pulses while it holds.
	var pulse: float = 6.0 + 2.0 * sin(zone.time_left_s * 12.0)
	zone.visual.scale = Vector3.ONE * pulse
	if zone.time_left_s > 0.0:
		return true
	var implode_radius_m: float = settings.get("implode_radius_m", 90.0)
	Splash.apply(get_tree(), zone.from, implode_radius_m, zone.info.amount, zone.info)
	if _fx != null:
		_fx.explosion(zone.from, implode_radius_m, Color(0.8, 0.5, 1.0))
	return false


func _target_within(at: Vector3, distance_m: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(CombatTarget.GROUP):
		var target: CombatTarget = node as CombatTarget
		if target != null and target.is_alive() and at.distance_to(target.get_aim_point()) - target.target_radius_m <= distance_m:
			return true
	return false


func _take_free() -> Shot:
	for shot: Shot in _shots:
		if not shot.active:
			return shot
	if not _pool_warning_shown:
		_pool_warning_shown = true
		push_warning("ProjectileSystem: pool of %d projectiles is exhausted; extra shots are dropped" % POOL_SIZE)
	return null


func _place_visual(shot: Shot) -> void:
	var direction: Vector3 = shot.velocity.normalized()
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var width: float = shot.block.get("size_m", 0.3)
	var length: float = shot.block.get("length_m", 2.0)
	shot.visual.global_transform = Transform3D(Basis.looking_at(direction, up).scaled_local(Vector3(width, width, length)), shot.position)
