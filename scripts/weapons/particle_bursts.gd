class_name ParticleBursts
extends Node3D
## Pooled GPU particle effects: explosion fire, smoke and debris, impact
## sparks and ejected shell casings.
##
## Every kind has a fixed pool of one-shot emitters that share one process
## material and one mesh. Showing an effect moves the next emitter of the pool
## and restarts it; nothing is created while playing. The graphics preset
## scales the pools (`max_active_particle_systems`), thins the particles
## (`particle_density`) and skips effects that are too far away to see
## (`effect_view_distance_m`).

enum Kind { FIRE, SMOKE, DEBRIS, SPARKS, SHELLS }

## Pool sizes at the reference budget of 160 particle systems.
const BASE_POOL: Dictionary = {Kind.FIRE: 14, Kind.SMOKE: 14, Kind.DEBRIS: 14, Kind.SPARKS: 28, Kind.SHELLS: 20}
const BASE_BUDGET: float = 160.0
## Particles per emitter at density 1. Built at MAX_DENSITY and thinned by `amount_ratio`.
const BASE_AMOUNT: Dictionary = {Kind.FIRE: 22, Kind.SMOKE: 12, Kind.DEBRIS: 18, Kind.SPARKS: 10, Kind.SHELLS: 1}
const LIFETIME_S: Dictionary = {Kind.FIRE: 0.55, Kind.SMOKE: 2.4, Kind.DEBRIS: 1.1, Kind.SPARKS: 0.35, Kind.SHELLS: 0.9}
const MAX_DENSITY: float = 1.5
## Sparks from a beam arrive every frame; this caps how many bursts start per second.
const MIN_SPARK_INTERVAL_S: float = 0.03
## Explosions closer to the camera than this (plus their radius) show debris only.
const NEAR_SKIP_M: float = 30.0

var _pools: Dictionary = {}  # Kind -> Array[GPUParticles3D]
var _next: Dictionary = {}  # Kind -> int
var _materials: Dictionary = {}  # Kind -> ParticleProcessMaterial
var _meshes: Dictionary = {}  # Kind -> Mesh
var _view_distance_m: float = 4000.0
var _spark_cooldown_s: float = 0.0
var _soft_texture: GradientTexture2D


func _ready() -> void:
	_build_resources()
	_rebuild_pools()
	Graphics.changed.connect(_rebuild_pools)


func _process(delta_s: float) -> void:
	_spark_cooldown_s = maxf(0.0, _spark_cooldown_s - delta_s)


## Fire, rising smoke and flying debris for an explosion of the given radius.
func explosion(at: Vector3, radius_m: float) -> void:
	if not _in_view(at, radius_m):
		return
	_burst(Kind.DEBRIS, Transform3D(Basis.from_scale(Vector3.ONE * radius_m), at))
	# Fire and smoke right at the camera would fade to nothing anyway (see the
	# distance fade of their material) but still be drawn over the whole screen.
	# A swarm ramming the turret cost three quarters of the frame rate that way.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_to(at) < NEAR_SKIP_M + radius_m:
		return
	_burst(Kind.FIRE, Transform3D(Basis.from_scale(Vector3.ONE * radius_m), at))
	if radius_m >= 4.0:
		_burst(Kind.SMOKE, Transform3D(Basis.from_scale(Vector3.ONE * radius_m), at))


## A spray of sparks leaving a surface along `normal`.
func sparks(at: Vector3, normal: Vector3, size: float = 1.0) -> void:
	if _spark_cooldown_s > 0.0 or not _in_view(at, size * 20.0):
		return
	_spark_cooldown_s = MIN_SPARK_INTERVAL_S
	var up: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var spark_basis: Basis = Basis(side, up, side.cross(up)).scaled(Vector3.ONE * size)
	_burst(Kind.SPARKS, Transform3D(spark_basis, at))


## One shell casing thrown out of a gun. `eject` is the socket's transform:
## the casing leaves along its +X axis. Drawn on the given render layers
## (the viewmodel layer, so it appears next to the gun).
func shell(eject: Transform3D, render_layers: int) -> void:
	var emitter: GPUParticles3D = _burst(Kind.SHELLS, eject.orthonormalized())
	if emitter != null:
		emitter.layers = render_layers


## A fire-and-smoke trail for something that falls from orbit. The caller adds
## the returned node to its own model; it is freed with it.
func make_reentry_trail(size_m: float) -> GPUParticles3D:
	var trail: GPUParticles3D = GPUParticles3D.new()
	trail.name = "ReentryTrail"
	trail.amount = maxi(8, int(60.0 * minf(float(Graphics.get_value("particle_density", 1.0)), MAX_DENSITY)))
	trail.lifetime = 1.4
	trail.local_coords = false
	trail.process_material = _make_trail_material(size_m)
	trail.draw_pass_1 = _meshes[Kind.FIRE]
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3.ONE * -600.0, Vector3.ONE * 1200.0)
	return trail


func _burst(kind: Kind, at: Transform3D) -> GPUParticles3D:
	var pool: Array = _pools.get(kind, [])
	if pool.is_empty():
		return null
	var index: int = _next[kind]
	_next[kind] = (index + 1) % pool.size()
	var emitter: GPUParticles3D = pool[index]
	emitter.global_transform = at
	emitter.restart()
	emitter.emitting = true
	return emitter


func _in_view(at: Vector3, size_m: float) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return true
	# Big effects stay visible from further away.
	return camera.global_position.distance_to(at) <= _view_distance_m + size_m * 20.0


func _rebuild_pools() -> void:
	for kind: Kind in _pools:
		for emitter: GPUParticles3D in _pools[kind]:
			emitter.queue_free()
	_pools.clear()
	_view_distance_m = Graphics.get_value("effect_view_distance_m", 4000.0)
	var density: float = clampf(float(Graphics.get_value("particle_density", 1.0)), 0.1, MAX_DENSITY)
	var budget: float = float(Graphics.get_value("max_active_particle_systems", 160)) / BASE_BUDGET
	for kind: Kind in BASE_POOL:
		var emitters: Array[GPUParticles3D] = []
		for index: int in maxi(2, int(round(float(BASE_POOL[kind]) * budget))):
			var emitter: GPUParticles3D = GPUParticles3D.new()
			emitter.name = "%s%d" % [Kind.keys()[kind], index]
			emitter.amount = maxi(1, int(ceil(float(BASE_AMOUNT[kind]) * MAX_DENSITY))) if kind != Kind.SHELLS else 1
			emitter.amount_ratio = density / MAX_DENSITY if kind != Kind.SHELLS else 1.0
			emitter.lifetime = LIFETIME_S[kind]
			emitter.one_shot = true
			emitter.explosiveness = 1.0 if kind != Kind.SMOKE else 0.8
			emitter.emitting = false
			emitter.local_coords = true
			emitter.process_material = _materials[kind]
			emitter.draw_pass_1 = _meshes[kind]
			emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			emitter.visibility_aabb = AABB(Vector3.ONE * -12.0, Vector3.ONE * 24.0)
			emitter.layers = Layers.RENDER_WORLD
			if kind == Kind.SPARKS or kind == Kind.DEBRIS:
				emitter.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
			add_child(emitter)
			emitters.append(emitter)
		_pools[kind] = emitters
		_next[kind] = 0


func _build_resources() -> void:
	var soft: Gradient = Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	_soft_texture = GradientTexture2D.new()
	_soft_texture.gradient = soft
	_soft_texture.fill = GradientTexture2D.FILL_RADIAL
	_soft_texture.fill_from = Vector2(0.5, 0.5)
	_soft_texture.fill_to = Vector2(1.0, 0.5)
	_soft_texture.width = 64
	_soft_texture.height = 64

	# Fire: a ball of hot puffs that swell, cool from white to deep red and fade.
	var fire: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fire.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.25
	fire.spread = 180.0
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 1.3
	fire.damping_min = 1.5
	fire.damping_max = 2.5
	fire.gravity = Vector3(0.0, 0.25, 0.0)
	fire.scale_min = 0.45
	fire.scale_max = 0.95
	fire.scale_curve = _curve([Vector2(0.0, 0.35), Vector2(0.25, 1.0), Vector2(1.0, 0.6)])
	fire.color_ramp = _ramp([Color(3.0, 2.6, 1.8, 1.0), Color(2.4, 1.1, 0.25, 0.9), Color(0.7, 0.12, 0.03, 0.5), Color(0.1, 0.02, 0.0, 0.0)], [0.0, 0.25, 0.65, 1.0])
	_materials[Kind.FIRE] = fire
	_meshes[Kind.FIRE] = _billboard_quad(Vector2(1.0, 1.0), true)

	# Smoke: dark puffs that drift up and thin out after the fire.
	var smoke: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smoke.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.35
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.08
	smoke.initial_velocity_max = 0.4
	smoke.damping_min = 0.2
	smoke.damping_max = 0.5
	smoke.gravity = Vector3(0.0, 0.12, 0.0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.scale_min = 0.7
	smoke.scale_max = 1.3
	smoke.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.3, 0.9), Vector2(1.0, 1.5)])
	smoke.color_ramp = _ramp([Color(0.2, 0.12, 0.08, 0.0), Color(0.09, 0.08, 0.08, 0.5), Color(0.1, 0.1, 0.1, 0.3), Color(0.12, 0.12, 0.12, 0.0)], [0.0, 0.15, 0.6, 1.0])
	_materials[Kind.SMOKE] = smoke
	_meshes[Kind.SMOKE] = _billboard_quad(Vector2(1.0, 1.0), false)

	# Debris: glowing fragments thrown outward that arc down.
	var debris: ParticleProcessMaterial = ParticleProcessMaterial.new()
	debris.spread = 180.0
	debris.initial_velocity_min = 1.2
	debris.initial_velocity_max = 3.6
	debris.damping_min = 0.6
	debris.damping_max = 1.2
	debris.gravity = Vector3(0.0, -1.6, 0.0)
	debris.scale_min = 0.5
	debris.scale_max = 1.2
	debris.color_ramp = _ramp([Color(3.0, 2.2, 1.2, 1.0), Color(2.0, 0.7, 0.15, 1.0), Color(0.4, 0.08, 0.02, 0.0)], [0.0, 0.5, 1.0])
	_materials[Kind.DEBRIS] = debris
	_meshes[Kind.DEBRIS] = _streak_quad(Vector2(0.035, 0.22))

	# Sparks: a short bright spray in a cone around the surface normal (+Y).
	var sparks_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	sparks_material.direction = Vector3.UP
	sparks_material.spread = 55.0
	sparks_material.initial_velocity_min = 5.0
	sparks_material.initial_velocity_max = 22.0
	sparks_material.damping_min = 2.0
	sparks_material.damping_max = 6.0
	sparks_material.gravity = Vector3(0.0, -14.0, 0.0)
	sparks_material.scale_min = 0.5
	sparks_material.scale_max = 1.3
	sparks_material.color_ramp = _ramp([Color(3.0, 2.8, 2.2, 1.0), Color(2.4, 1.2, 0.3, 1.0), Color(0.6, 0.1, 0.0, 0.0)], [0.0, 0.4, 1.0])
	_materials[Kind.SPARKS] = sparks_material
	_meshes[Kind.SPARKS] = _streak_quad(Vector2(0.05, 0.7))

	# Shell casings: one brass case flipped out sideways (+X of the socket).
	var shells: ParticleProcessMaterial = ParticleProcessMaterial.new()
	shells.direction = Vector3(1.0, 0.45, 0.1)
	shells.spread = 12.0
	shells.initial_velocity_min = 2.2
	shells.initial_velocity_max = 3.4
	shells.gravity = Vector3(0.0, -9.8, 0.0)
	shells.angular_velocity_min = -900.0
	shells.angular_velocity_max = 900.0
	shells.angle_min = -40.0
	shells.angle_max = 40.0
	_materials[Kind.SHELLS] = shells
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.58, 0.22)
	brass.metallic = 0.9
	brass.roughness = 0.35
	var casing: CylinderMesh = CylinderMesh.new()
	casing.top_radius = 0.012
	casing.bottom_radius = 0.014
	casing.height = 0.07
	casing.radial_segments = 8
	casing.rings = 1
	casing.material = brass
	_meshes[Kind.SHELLS] = casing


func _make_trail_material(size_m: float) -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = size_m * 0.4
	material.spread = 180.0
	material.initial_velocity_min = size_m * 0.2
	material.initial_velocity_max = size_m * 1.0
	material.gravity = Vector3.ZERO
	material.scale_min = size_m * 1.2
	material.scale_max = size_m * 2.4
	material.scale_curve = _curve([Vector2(0.0, 0.6), Vector2(0.3, 1.0), Vector2(1.0, 1.6)])
	material.color_ramp = _ramp([Color(3.0, 2.2, 1.2, 0.9), Color(2.0, 0.7, 0.15, 0.6), Color(0.35, 0.2, 0.15, 0.25), Color(0.2, 0.2, 0.2, 0.0)], [0.0, 0.2, 0.55, 1.0])
	return material


## A camera-facing quad with a soft round texture, coloured by the particle.
func _billboard_quad(size: Vector2, additive: bool) -> QuadMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_texture
	material.disable_receive_shadows = true
	# Puffs right in front of the camera fade out instead of covering the screen.
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 4.0
	material.distance_fade_max_distance = 45.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


## A thin bright quad that the emitter turns along the particle's velocity.
func _streak_quad(size: Vector2) -> QuadMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_texture
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


static func _ramp(colors: Array[Color], offsets: Array[float]) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _curve(points: Array[Vector2]) -> CurveTexture:
	var curve: Curve = Curve.new()
	var highest: float = 1.0
	for point: Vector2 in points:
		highest = maxf(highest, point.y)
	curve.max_value = highest
	for point: Vector2 in points:
		curve.add_point(point)
	var texture: CurveTexture = CurveTexture.new()
	texture.curve = curve
	return texture
