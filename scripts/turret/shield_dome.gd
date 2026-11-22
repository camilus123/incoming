class_name ShieldDome
extends ShieldVisual
## Shield style "dome": a bubble around the emplacement that ripples where
## it is hit.

const SHADER_ASSET: String = "vfx.shader.shield_dome"
const MAX_IMPACTS: int = 8
const RIPPLE_LIFE_S: float = 0.9
const FLASH_DECAY_PER_S: float = 2.5
## How fast the whole shield fades out again after a hit.
const ACTIVITY_DECAY_PER_S: float = 0.9

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _impacts: Array[Vector4] = []
var _active_count: int = 0
var _flash: float = 0.0
var _activity: float = 0.0
var _idle_alpha: float = 0.0
var _radius_m: float = 14.0


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader
	_material.set_shader_parameter(&"ripple_life", RIPPLE_LIFE_S)
	for index: int in MAX_IMPACTS:
		_impacts.append(Vector4(0.0, 1.0, 0.0, -1.0))

	var sphere: SphereMesh = SphereMesh.new()
	sphere.is_hemisphere = true
	sphere.radial_segments = 64
	sphere.rings = 24
	sphere.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.layers = Layers.RENDER_WORLD
	add_child(_mesh)


func get_style() -> String:
	return "dome"


func configure(visuals: Dictionary) -> void:
	_radius_m = visuals.get("dome_radius_m", 14.0)
	var sphere: SphereMesh = _mesh.mesh as SphereMesh
	sphere.radius = _radius_m
	sphere.height = _radius_m
	var color: Array = visuals.get("color", [0.3, 0.8, 1.0])
	_material.set_shader_parameter(&"shield_color", Color(color[0], color[1], color[2]))
	var low: Array = visuals.get("low_color", [1.0, 0.42, 0.08])
	_material.set_shader_parameter(&"low_color", Color(low[0], low[1], low[2]))
	_idle_alpha = visuals.get("idle_alpha", 0.0)
	_material.set_shader_parameter(&"idle_alpha", _idle_alpha)
	_update_visibility()


func set_charge(fraction: float) -> void:
	_material.set_shader_parameter(&"charge", clampf(fraction, 0.0, 1.0))


## Starts a ripple where a hit coming from `from_position` meets the dome.
func add_impact(from_position: Vector3) -> void:
	var direction: Vector3 = to_local(from_position)
	if direction.length_squared() < 0.0001:
		direction = Vector3.UP
	direction = direction.normalized()
	direction.y = maxf(direction.y, 0.05)
	direction = direction.normalized()
	# Live ripples are packed at the front; when all slots are busy the oldest (first) is replaced.
	var slot: int = _active_count if _active_count < MAX_IMPACTS else 0
	_impacts[slot] = Vector4(direction.x, direction.y, direction.z, 0.0)
	_active_count = mini(_active_count + 1, MAX_IMPACTS)
	_activity = 1.0
	_update_visibility()


func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength)
	_update_visibility()


## An invisible dome is not drawn at all: its shader would still run for
## every pixel of the screen.
func _update_visibility() -> void:
	_mesh.visible = _idle_alpha > 0.0 or _active_count > 0 or _flash > 0.0 or _activity > 0.0


func _process(delta_s: float) -> void:
	if _active_count == 0 and _flash <= 0.0 and _activity <= 0.0:
		return
	# Age the ripples and pack the live ones to the front for the shader.
	var live: int = 0
	for index: int in MAX_IMPACTS:
		var impact: Vector4 = _impacts[index]
		if impact.w < 0.0:
			continue
		impact.w += delta_s
		_impacts[index] = Vector4(0.0, 1.0, 0.0, -1.0)
		if impact.w <= RIPPLE_LIFE_S:
			_impacts[live] = impact
			live += 1
	_active_count = live
	_flash = maxf(0.0, _flash - FLASH_DECAY_PER_S * delta_s)
	_activity = maxf(0.0, _activity - ACTIVITY_DECAY_PER_S * delta_s)
	_material.set_shader_parameter(&"impacts", _impacts)
	_material.set_shader_parameter(&"impact_count", live)
	_material.set_shader_parameter(&"flash", _flash)
	_material.set_shader_parameter(&"activity", _activity)
	_update_visibility()
