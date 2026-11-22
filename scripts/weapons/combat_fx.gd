class_name CombatFx
extends Node3D
## Pooled combat effects: tracers, flashes and explosions.
##
## Nothing is instanced while playing. Tracers and flashes are slots of two
## [GlowBatch] pools (one draw call each); when a pool is full the oldest
## effect is reused. Gameplay code calls the public functions and never
## touches the nodes.

const GROUP: StringName = &"combat_fx"
const TRACER_POOL: int = 64
const FLASH_POOL: int = 64
const LIGHT_POOL: int = 8

var _tracers: GlowBatch
var _flashes: GlowBatch
var _bursts: ParticleBursts

var _lights: Array[OmniLight3D] = []
var _light_life: PackedFloat32Array = []
var _light_max_life: PackedFloat32Array = []
var _light_energy: PackedFloat32Array = []
var _next_light: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	_tracers = GlowBatch.create(box, TRACER_POOL, "Tracers")
	add_child(_tracers)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_flashes = GlowBatch.create(sphere, FLASH_POOL, "Flashes")
	add_child(_flashes)

	_bursts = ParticleBursts.new()
	_bursts.name = "ParticleBursts"
	add_child(_bursts)

	for index: int in LIGHT_POOL:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "ExplosionLight%d" % index
		light.visible = false
		light.shadow_enabled = false
		# Lights must be on the viewmodel layer too, or the guns would not be lit by them.
		light.layers = Layers.RENDER_WORLD | Layers.RENDER_VIEWMODEL
		add_child(light)
		_lights.append(light)
	_light_life.resize(LIGHT_POOL)
	_light_max_life.resize(LIGHT_POOL)
	_light_energy.resize(LIGHT_POOL)


## Shows a straight glowing line from `from` to `to` that fades over `life_s`.
func tracer(from: Vector3, to: Vector3, color: Color, width_m: float, life_s: float, intensity: float = 4.0) -> void:
	var span: Vector3 = to - from
	var length: float = span.length()
	if length < 0.01:
		return
	var direction: Vector3 = span / length
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var tracer_basis: Basis = Basis.looking_at(direction, up).scaled_local(Vector3(width_m, width_m, length))
	_tracers.show_timed(_tracers.take_slot(), Transform3D(tracer_basis, from + span * 0.5), color, intensity, life_s)


## Shows a glowing sphere that grows from `start_radius_m` to `end_radius_m`
## while fading out. Used for muzzle flashes and impacts.
func flash(at: Vector3, start_radius_m: float, end_radius_m: float, color: Color, life_s: float, intensity: float = 4.0) -> void:
	var end_radius: float = maxf(end_radius_m, 0.001)
	_flashes.show_timed(_flashes.take_slot(), Transform3D(Basis.from_scale(Vector3.ONE * end_radius), at), color, intensity, life_s, start_radius_m / end_radius)


## Sparks thrown off a surface that was hit. `normal` points away from the
## surface (towards the shooter is fine). Sized up with distance so far hits
## still read.
func sparks(at: Vector3, normal: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var distance: float = camera.global_position.distance_to(at) if camera != null else 100.0
	_bursts.sparks(at, normal, clampf(distance / 70.0, 1.0, 30.0))


## A shell casing thrown out of a gun at the `eject` socket (viewmodel layer).
func shell(eject: Transform3D, render_layers: int) -> void:
	_bursts.shell(eject, render_layers)


## A fire-and-smoke trail node for an enemy that falls from orbit.
func make_reentry_trail(size_m: float) -> GPUParticles3D:
	return _bursts.make_reentry_trail(size_m)


## A fireball with fire, smoke and debris particles and a short light pulse.
func explosion(at: Vector3, radius_m: float, color: Color) -> void:
	_bursts.explosion(at, radius_m)
	EventBus.explosion.emit(at, radius_m)
	flash(at, radius_m * 0.25, radius_m, color, 0.45, 5.0)
	flash(at, radius_m * 0.1, radius_m * 0.55, Color(1.0, 0.95, 0.8), 0.22, 9.0)
	var index: int = _next_light
	_next_light = (_next_light + 1) % LIGHT_POOL
	var light: OmniLight3D = _lights[index]
	light.global_position = at
	light.light_color = color
	light.omni_range = radius_m * 12.0
	light.visible = true
	_light_life[index] = 0.3
	_light_max_life[index] = 0.3
	_light_energy[index] = 6.0


func _process(delta_s: float) -> void:
	for index: int in LIGHT_POOL:
		if _light_life[index] <= 0.0:
			continue
		_light_life[index] -= delta_s
		var light: OmniLight3D = _lights[index]
		if _light_life[index] <= 0.0:
			light.visible = false
			continue
		light.light_energy = _light_energy[index] * _light_life[index] / _light_max_life[index]
