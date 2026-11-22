class_name GlowBatch
extends MultiMeshInstance3D
## A fixed pool of glowing shapes drawn as one MultiMesh (one draw call).
##
## Used for tracers, flashes, bolts and explosions. A slot is filled once and
## the shader does the fading and growing from the batch clock, so nothing is
## updated per effect per frame. When the pool is full the oldest slot is reused.

const SHADER_ASSET: String = "vfx.shader.glow_unlit"

var _material: ShaderMaterial
var _clock_s: float = 0.0
var _next: int = 0
var _capacity: int = 0


## Creates a batch of `capacity` copies of `shape` (a mesh of unit size).
static func create(shape: Mesh, capacity: int, batch_name: String) -> GlowBatch:
	var batch: GlowBatch = GlowBatch.new()
	batch.name = batch_name
	batch._capacity = capacity
	batch._material = ShaderMaterial.new()
	batch._material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = shape
	multimesh.instance_count = capacity
	# Instances are anywhere in the world; never cull the batch as a whole.
	multimesh.custom_aabb = AABB(Vector3.ONE * -40000.0, Vector3.ONE * 80000.0)
	batch.multimesh = multimesh
	batch.material_override = batch._material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.layers = Layers.RENDER_WORLD
	for index: int in capacity:
		batch.hide_slot(index)
	return batch


## The next slot, round robin (the oldest effect is overwritten when full).
func take_slot() -> int:
	var index: int = _next
	_next = (_next + 1) % _capacity
	return index


## Shows a shape that fades out over `life_s` while growing from
## `start_scale` times its size to the full size of `shape_transform`.
func show_timed(index: int, shape_transform: Transform3D, color: Color, intensity: float, life_s: float, start_scale: float = 1.0) -> void:
	multimesh.set_instance_transform(index, shape_transform)
	multimesh.set_instance_color(index, color)
	multimesh.set_instance_custom_data(index, Color(_clock_s, maxf(life_s, 0.001), start_scale, intensity))


## Shows a shape that stays until `hide_slot`. Move it with `move_slot`.
func show_steady(index: int, shape_transform: Transform3D, color: Color, intensity: float) -> void:
	multimesh.set_instance_transform(index, shape_transform)
	multimesh.set_instance_color(index, color)
	multimesh.set_instance_custom_data(index, Color(0.0, 0.0, 1.0, intensity))


func move_slot(index: int, shape_transform: Transform3D) -> void:
	multimesh.set_instance_transform(index, shape_transform)


func hide_slot(index: int) -> void:
	multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _process(delta_s: float) -> void:
	_clock_s += delta_s
	_material.set_shader_parameter(&"now", _clock_s)
