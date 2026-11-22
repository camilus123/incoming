class_name ShieldSkin
extends ShieldVisual
## Shield style "conformal": an energy shell that follows the shape of the
## turret and guns, floating a little above the hull.
##
## For every mesh of the turret model a shell mesh is generated: the same
## shape, grown outwards by `conformal_offset_m`. Vertices that share a
## position move together (along the sum of their face normals), so the shell
## stays closed at hard edges and corners instead of splitting into loose
## faces. Because it is built from the real meshes it fits any replacement
## model. A hit sends a bright wave around the turret, starting on the side
## the hit came from.

const SHADER_ASSET: String = "vfx.shader.shield_skin"
const SHELL_NAME: StringName = &"ShieldShell"
## Marks generated shells, so a shell never gets a shell of its own.
const SHELL_META: StringName = &"shield_shell"
const MAX_IMPACTS: int = 4
const WAVE_LIFE_S: float = 0.6
const FLASH_DECAY_PER_S: float = 2.5
## How fast the whole shield fades out again after a hit.
const ACTIVITY_DECAY_PER_S: float = 0.9
## Positions closer than this (in metres) count as the same corner.
const WELD_GRID_M: float = 0.0005

var _material: ShaderMaterial
var _shells: Array[MeshInstance3D] = []
var _shell_cache: Dictionary = {}  # source Mesh -> ArrayMesh
var _offset_m: float = 0.06
var _impacts: Array[Vector4] = []
var _active_count: int = 0
var _flash: float = 0.0
var _activity: float = 0.0


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
	var low: Array = visuals.get("low_color", [1.0, 0.42, 0.08])
	_material.set_shader_parameter(&"low_color", Color(low[0], low[1], low[2]))
	_material.set_shader_parameter(&"idle_alpha", visuals.get("idle_alpha", 0.0))
	var offset_m: float = visuals.get("conformal_offset_m", 0.06)
	if not is_equal_approx(offset_m, _offset_m):
		_offset_m = offset_m
		_shell_cache.clear()


func attach(model_root: Node3D) -> void:
	detach()
	_cover(model_root)
	_material.set_shader_parameter(&"centre", global_position + Vector3.UP * 1.5)


func detach() -> void:
	for shell: MeshInstance3D in _shells:
		if is_instance_valid(shell):
			# Freed at once: a shell still in the tree would be covered again by the next attach.
			shell.free()
	_shells.clear()


func set_charge(fraction: float) -> void:
	_material.set_shader_parameter(&"charge", clampf(fraction, 0.0, 1.0))


func add_impact(from_position: Vector3) -> void:
	var direction: Vector3 = from_position - (global_position + Vector3.UP * 1.5)
	direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	var slot: int = _active_count if _active_count < MAX_IMPACTS else 0
	_impacts[slot] = Vector4(direction.x, direction.y, direction.z, 0.0)
	_active_count = mini(_active_count + 1, MAX_IMPACTS)
	_activity = 1.0


func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength)


func _exit_tree() -> void:
	detach()


func _process(delta_s: float) -> void:
	if _active_count == 0 and _flash <= 0.0 and _activity <= 0.0:
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
	_activity = maxf(0.0, _activity - ACTIVITY_DECAY_PER_S * delta_s)
	_material.set_shader_parameter(&"impacts", _impacts)
	_material.set_shader_parameter(&"impact_count", live)
	_material.set_shader_parameter(&"flash", _flash)
	_material.set_shader_parameter(&"activity", _activity)


## Adds a shell to every mesh under `node`.
func _cover(node: Node) -> void:
	if node.has_meta(SHELL_META):
		return
	var source: MeshInstance3D = node as MeshInstance3D
	if source != null and source.mesh != null:
		var shell: MeshInstance3D = MeshInstance3D.new()
		shell.name = SHELL_NAME
		shell.set_meta(SHELL_META, true)
		shell.mesh = _get_shell_mesh(source.mesh)
		shell.material_override = _material
		shell.layers = source.layers
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(shell)
		_shells.append(shell)
	for child: Node in node.get_children():
		_cover(child)


func _get_shell_mesh(source: Mesh) -> ArrayMesh:
	if not _shell_cache.has(source):
		_shell_cache[source] = build_shell_mesh(source, _offset_m)
	return _shell_cache[source]


## Returns a copy of `source` grown outwards by `offset_m`, with shared
## corners kept together. Static and free of scene access so it can be tested.
static func build_shell_mesh(source: Mesh, offset_m: float) -> ArrayMesh:
	var shell: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		if vertices.is_empty() or not normals is PackedVector3Array:
			continue
		var vertex_normals: PackedVector3Array = normals

		# Collect the distinct face normals that meet at each position.
		var corners: Dictionary = {}  # welded position -> Array of distinct normals
		for index: int in vertices.size():
			var key: Vector3i = Vector3i((vertices[index] / WELD_GRID_M).round())
			var normal: Vector3 = vertex_normals[index]
			var known: Array = corners.get_or_add(key, [])
			var is_new: bool = true
			for other: Vector3 in known:
				if other.dot(normal) > 0.999:
					is_new = false
					break
			if is_new:
				known.append(normal)

		# Move every vertex along the sum of the normals at its position: each
		# face moves out by the offset and the faces stay joined at the edge.
		var grown: PackedVector3Array = PackedVector3Array()
		grown.resize(vertices.size())
		for index: int in vertices.size():
			var key: Vector3i = Vector3i((vertices[index] / WELD_GRID_M).round())
			var push: Vector3 = Vector3.ZERO
			for normal: Vector3 in corners[key]:
				push += normal
			# Many nearly parallel normals (a cone tip) must not shoot the corner far out.
			if push.length() > 2.0:
				push = push.normalized() * 2.0
			grown[index] = vertices[index] + push * offset_m

		var shell_arrays: Array = []
		shell_arrays.resize(Mesh.ARRAY_MAX)
		shell_arrays[Mesh.ARRAY_VERTEX] = grown
		shell_arrays[Mesh.ARRAY_NORMAL] = vertex_normals
		shell_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell_arrays)
	return shell
