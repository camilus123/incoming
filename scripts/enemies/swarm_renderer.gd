class_name SwarmRenderer
extends Node3D
## Draws every swarm enemy (data field "swarm") of one model as one MultiMesh:
## one draw call for the whole swarm instead of a model scene per drone.
##
## The model's meshes are merged once into a single mesh (one surface per
## material). Each frame the enemy manager hands over the transforms of the
## live members; nothing else is touched.

const START_CAPACITY: int = 128

var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _count: int = 0


## Builds a renderer for a model asset id. Returns null if the model has no meshes.
static func create(model_id: String, model_scale: float) -> SwarmRenderer:
	var scene: PackedScene = GameData.assets.load_asset(model_id) as PackedScene
	if scene == null:
		return null
	var model: Node3D = scene.instantiate() as Node3D
	var mesh: ArrayMesh = merge_meshes(model, model_scale)
	model.free()
	if mesh == null:
		return null
	var renderer: SwarmRenderer = SwarmRenderer.new()
	renderer.name = "Swarm_%s" % model_id.replace(".", "_")
	renderer._multimesh = MultiMesh.new()
	renderer._multimesh.transform_format = MultiMesh.TRANSFORM_3D
	renderer._multimesh.mesh = mesh
	renderer._multimesh.instance_count = START_CAPACITY
	renderer._multimesh.visible_instance_count = 0
	# Members are spread over kilometres; never cull the swarm as a whole.
	renderer._multimesh.custom_aabb = AABB(Vector3.ONE * -20000.0, Vector3.ONE * 40000.0)
	renderer._instance = MultiMeshInstance3D.new()
	renderer._instance.multimesh = renderer._multimesh
	renderer._instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer._instance.layers = Layers.RENDER_WORLD
	renderer.add_child(renderer._instance)
	return renderer


## Merges every mesh under `model` into one mesh in the model's own space,
## with one surface per material. Returns null if there is nothing to merge.
static func merge_meshes(model: Node3D, model_scale: float = 1.0) -> ArrayMesh:
	var tools: Dictionary = {}  # Material -> SurfaceTool
	_collect(model, Transform3D(Basis.from_scale(Vector3.ONE * model_scale), Vector3.ZERO), tools)
	if tools.is_empty():
		return null
	var merged: ArrayMesh = ArrayMesh.new()
	for material: Variant in tools:
		var tool: SurfaceTool = tools[material]
		tool.commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, material as Material)
	return merged


## Starts a new frame: members are added with `add()` after this.
func begin() -> void:
	_count = 0


## Adds one member to this frame.
func add(member: Transform3D) -> void:
	if _count >= _multimesh.instance_count:
		# Doubling keeps regrowth rare; earlier members are re-added next frame.
		_multimesh.instance_count *= 2
	_multimesh.set_instance_transform(_count, member)
	_count += 1


## Ends the frame: only the members added since `begin()` are drawn.
func finish() -> void:
	_multimesh.visible_instance_count = _count


func get_count() -> int:
	return _count


static func _collect(node: Node, parent_transform: Transform3D, tools: Dictionary) -> void:
	var node_transform: Transform3D = parent_transform
	if node is Node3D and node.get_parent() != null:
		node_transform = parent_transform * (node as Node3D).transform
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for surface: int in instance.mesh.get_surface_count():
			var material: Material = instance.get_active_material(surface)
			if not tools.has(material):
				var tool: SurfaceTool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = tool
			(tools[material] as SurfaceTool).append_from(instance.mesh, surface, node_transform)
	for child: Node in node.get_children():
		_collect(child, node_transform, tools)
