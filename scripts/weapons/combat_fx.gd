class_name CombatFx
extends Node3D
## Pooled combat effects: tracers, flashes and explosions.
##
## Nothing is instanced while playing. Each effect type has a fixed pool of
## meshes that share one material; when the pool is full the oldest effect is
## reused. Gameplay code calls the three public functions and never touches
## the nodes.

const GROUP: StringName = &"combat_fx"
const SHADER_ASSET: String = "vfx.shader.glow_unlit"
const TRACER_POOL: int = 64
const FLASH_POOL: int = 64
const LIGHT_POOL: int = 8

var _tracers: Array[MeshInstance3D] = []
var _tracer_life: PackedFloat32Array = []
var _tracer_max_life: PackedFloat32Array = []
var _tracer_colors: PackedColorArray = []
var _next_tracer: int = 0

var _flashes: Array[MeshInstance3D] = []
var _flash_life: PackedFloat32Array = []
var _flash_max_life: PackedFloat32Array = []
var _flash_start_radius: PackedFloat32Array = []
var _flash_end_radius: PackedFloat32Array = []
var _flash_colors: PackedColorArray = []
var _next_flash: int = 0

var _lights: Array[OmniLight3D] = []
var _light_life: PackedFloat32Array = []
var _light_max_life: PackedFloat32Array = []
var _light_energy: PackedFloat32Array = []
var _next_light: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	for index: int in TRACER_POOL:
		_tracers.append(_make_instance(box, "Tracer%d" % index))
	_tracer_life.resize(TRACER_POOL)
	_tracer_max_life.resize(TRACER_POOL)
	_tracer_colors.resize(TRACER_POOL)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = material
	for index: int in FLASH_POOL:
		_flashes.append(_make_instance(sphere, "Flash%d" % index))
	_flash_life.resize(FLASH_POOL)
	_flash_max_life.resize(FLASH_POOL)
	_flash_start_radius.resize(FLASH_POOL)
	_flash_end_radius.resize(FLASH_POOL)
	_flash_colors.resize(FLASH_POOL)

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
	var index: int = _next_tracer
	_next_tracer = (_next_tracer + 1) % TRACER_POOL
	var direction: Vector3 = span / length
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var tracer_basis: Basis = Basis.looking_at(direction, up).scaled_local(Vector3(width_m, width_m, length))
	var instance: MeshInstance3D = _tracers[index]
	instance.global_transform = Transform3D(tracer_basis, from + span * 0.5)
	instance.set_instance_shader_parameter(&"tint", color)
	instance.set_instance_shader_parameter(&"intensity", intensity)
	instance.visible = true
	_tracer_life[index] = life_s
	_tracer_max_life[index] = life_s
	_tracer_colors[index] = color


## Shows a glowing sphere that grows from `start_radius_m` to `end_radius_m`
## while fading out. Used for muzzle flashes and impacts.
func flash(at: Vector3, start_radius_m: float, end_radius_m: float, color: Color, life_s: float, intensity: float = 4.0) -> void:
	var index: int = _next_flash
	_next_flash = (_next_flash + 1) % FLASH_POOL
	var instance: MeshInstance3D = _flashes[index]
	instance.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * start_radius_m), at)
	instance.set_instance_shader_parameter(&"tint", color)
	instance.set_instance_shader_parameter(&"intensity", intensity)
	instance.visible = true
	_flash_life[index] = life_s
	_flash_max_life[index] = life_s
	_flash_start_radius[index] = start_radius_m
	_flash_end_radius[index] = end_radius_m
	_flash_colors[index] = color


## A fireball with a short light pulse.
func explosion(at: Vector3, radius_m: float, color: Color) -> void:
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
	for index: int in TRACER_POOL:
		if _tracer_life[index] <= 0.0:
			continue
		_tracer_life[index] -= delta_s
		var instance: MeshInstance3D = _tracers[index]
		if _tracer_life[index] <= 0.0:
			instance.visible = false
			continue
		var color: Color = _tracer_colors[index]
		color.a = _tracer_life[index] / _tracer_max_life[index]
		instance.set_instance_shader_parameter(&"tint", color)

	for index: int in FLASH_POOL:
		if _flash_life[index] <= 0.0:
			continue
		_flash_life[index] -= delta_s
		var instance: MeshInstance3D = _flashes[index]
		if _flash_life[index] <= 0.0:
			instance.visible = false
			continue
		var remaining: float = _flash_life[index] / _flash_max_life[index]
		var radius: float = lerpf(_flash_end_radius[index], _flash_start_radius[index], remaining * remaining)
		instance.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * radius), instance.global_position)
		var color: Color = _flash_colors[index]
		color.a = remaining
		instance.set_instance_shader_parameter(&"tint", color)

	for index: int in LIGHT_POOL:
		if _light_life[index] <= 0.0:
			continue
		_light_life[index] -= delta_s
		var light: OmniLight3D = _lights[index]
		if _light_life[index] <= 0.0:
			light.visible = false
			continue
		light.light_energy = _light_energy[index] * _light_life[index] / _light_max_life[index]


func _make_instance(mesh: Mesh, instance_name: String) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = instance_name
	instance.mesh = mesh
	instance.visible = false
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.layers = Layers.RENDER_WORLD
	add_child(instance)
	return instance
