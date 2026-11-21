class_name ShieldSkin
extends ShieldVisual
## Shield style "conformal": an energy skin that hugs the turret and guns.
##
## It is a material overlay on every mesh of the turret model, so it follows
## the real shape of whatever models are installed. A hit sends a bright wave
## around the turret, starting on the side the hit came from.

const SHADER_ASSET: String = "vfx.shader.shield_skin"
const MAX_IMPACTS: int = 4
const WAVE_LIFE_S: float = 0.6
const FLASH_DECAY_PER_S: float = 2.5

var _material: ShaderMaterial
var _covered: Array[GeometryInstance3D] = []
var _impacts: Array[Vector4] = []
var _active_count: int = 0
var _flash: float = 0.0


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader
	_material.set_shader_parameter(&"wave_life", WAVE_LIFE_S)
	for index: int in MAX_IMPACTS:
		_impacts.append(Vector4(0.0, 1.0, 0.0, -1.0))


func get_style() -> String:
	return "conformal"


func configure(visuals: Dictionary) -> void:
	var color: Array = visuals.get("color", [0.3, 0.8, 1.0])
	_material.set_shader_parameter(&"shield_color", Color(color[0], color[1], color[2]))


func attach(model_root: Node3D) -> void:
	detach()
	_cover(model_root)
	_material.set_shader_parameter(&"centre", global_position + Vector3.UP * 1.5)


func detach() -> void:
	for instance: GeometryInstance3D in _covered:
		if is_instance_valid(instance) and instance.material_overlay == _material:
			instance.material_overlay = null
	_covered.clear()


func set_charge(fraction: float) -> void:
	_material.set_shader_parameter(&"charge", clampf(fraction, 0.0, 1.0))


func add_impact(from_position: Vector3) -> void:
	var direction: Vector3 = from_position - (global_position + Vector3.UP * 1.5)
	direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	var slot: int = _active_count if _active_count < MAX_IMPACTS else 0
	_impacts[slot] = Vector4(direction.x, direction.y, direction.z, 0.0)
	_active_count = mini(_active_count + 1, MAX_IMPACTS)


func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength)


func _exit_tree() -> void:
	detach()


func _process(delta_s: float) -> void:
	if _active_count == 0 and _flash <= 0.0:
		return
	var live: int = 0
	for index: int in MAX_IMPACTS:
		var impact: Vector4 = _impacts[index]
		if impact.w < 0.0:
			continue
		impact.w += delta_s
		_impacts[index] = Vector4(0.0, 1.0, 0.0, -1.0)
		if impact.w <= WAVE_LIFE_S:
			_impacts[live] = impact
			live += 1
	_active_count = live
	_flash = maxf(0.0, _flash - FLASH_DECAY_PER_S * delta_s)
	_material.set_shader_parameter(&"impacts", _impacts)
	_material.set_shader_parameter(&"impact_count", live)
	_material.set_shader_parameter(&"flash", _flash)


func _cover(node: Node) -> void:
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null:
		instance.material_overlay = _material
		_covered.append(instance)
	for child: Node in node.get_children():
		_cover(child)
