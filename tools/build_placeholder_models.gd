extends SceneTree
## Builds the placeholder models from primitives and writes them as .glb files.
##
## Usage (from the project folder), then re-import:
##   godot --headless --path . --script res://tools/build_placeholder_models.gd
##   godot --headless --path . --import
##
## The output follows the socket conventions in docs/ASSETS.md, so each file
## can be replaced by a real model with the same socket names. Forward is -Z.

const OUT_DIR: String = "res://assets/models"

var _gunmetal: StandardMaterial3D
var _armour: StandardMaterial3D
var _dark: StandardMaterial3D
var _concrete: StandardMaterial3D
var _amber: StandardMaterial3D
var _lens: StandardMaterial3D
var _target_white: StandardMaterial3D
var _target_orange: StandardMaterial3D
var _engine_glow: StandardMaterial3D
var _enemy_hull: StandardMaterial3D
var _enemy_panel: StandardMaterial3D
var _enemy_eye: StandardMaterial3D


func _init() -> void:
	_make_materials()
	var failed: int = 0
	failed += _export(_build_turret_base(), "turret/turret_base.glb")
	failed += _export(_build_pulse_laser(), "weapons/pulse_laser.glb")
	failed += _export(_build_missile_pod(), "weapons/missile_pod.glb")
	failed += _export(_build_micro_missile(), "projectiles/micro_missile.glb")
	failed += _export(_build_target_dummy(), "targets/target_dummy.glb")
	failed += _export(_build_drone(), "enemies/drone_swarmer.glb")
	failed += _export(_build_interceptor(), "enemies/interceptor.glb")
	failed += _export(_build_bomber(), "enemies/bomber.glb")
	failed += _export(_build_enemy_bomb(), "projectiles/enemy_bomb.glb")
	print("Placeholder models built, %d failed." % failed)
	quit(1 if failed > 0 else 0)


# --- Models -----------------------------------------------------------------

func _build_turret_base() -> Node3D:
	var root: Node3D = _node(null, "TurretBase", Vector3.ZERO)
	_cylinder(root, "Pad", 3.2, 0.4, Vector3(0, 0.2, 0), Vector3.ZERO, _concrete)
	_cylinder(root, "PadRim", 3.3, 0.12, Vector3(0, 0.06, 0), Vector3.ZERO, _dark)
	_cylinder(root, "YawRing", 1.7, 0.3, Vector3(0, 0.55, 0), Vector3.ZERO, _gunmetal)

	var yaw: Node3D = _node(root, "Pivot_Yaw", Vector3(0, 0.7, 0))
	_box(yaw, "Body", Vector3(2.4, 0.9, 2.2), Vector3(0, 0.45, 0.35), _armour)
	_box(yaw, "BodyStripe", Vector3(2.42, 0.08, 2.22), Vector3(0, 0.78, 0.35), _amber)
	_box(yaw, "TrunnionLeft", Vector3(0.3, 1.1, 0.9), Vector3(-1.35, 1.05, 0.1), _gunmetal)
	_box(yaw, "TrunnionRight", Vector3(0.3, 1.1, 0.9), Vector3(1.35, 1.05, 0.1), _gunmetal)
	_box(yaw, "RearHousing", Vector3(1.6, 0.9, 0.8), Vector3(0, 1.2, 1.2), _armour)

	var pitch: Node3D = _node(yaw, "Pivot_Pitch", Vector3(0, 1.3, 0))
	_box(pitch, "Cradle", Vector3(2.3, 0.3, 1.8), Vector3(0, -0.62, -0.3), _gunmetal)
	_cylinder(pitch, "Axle", 0.16, 2.9, Vector3(0, 0, 0.1), Vector3(0, 0, 90), _dark)
	_node(pitch, "ViewAnchor", Vector3(0, 0.35, 0.4))
	_node(pitch, "Mount_Primary", Vector3(0, -0.4, -0.6))
	_node(pitch, "Mount_Alternate", Vector3(1.5, -0.35, -1.0))
	return root


func _build_pulse_laser() -> Node3D:
	var root: Node3D = _node(null, "PulseLaser", Vector3.ZERO)
	_box(root, "Housing", Vector3(1.6, 0.34, 0.9), Vector3(0, 0, 0.1), _armour)
	_box(root, "Capacitor", Vector3(0.6, 0.22, 0.5), Vector3(0, 0.26, 0.2), _gunmetal)
	for side: int in [-1, 1]:
		var x: float = 0.58 * side
		var suffix: String = "Left" if side < 0 else "Right"
		_cylinder(root, "Barrel" + suffix, 0.065, 2.5, Vector3(x, 0, -1.55), Vector3(90, 0, 0), _gunmetal)
		_cylinder(root, "Sleeve" + suffix, 0.11, 0.9, Vector3(x, 0, -0.8), Vector3(90, 0, 0), _dark)
		for fin: int in 5:
			_box(root, "Fin%s%d" % [suffix, fin], Vector3(0.26, 0.26, 0.035), Vector3(x, 0, -1.45 - 0.22 * fin), _gunmetal)
		_cylinder(root, "Lens" + suffix, 0.085, 0.07, Vector3(x, 0, -2.8), Vector3(90, 0, 0), _lens)
	_node(root, "Muzzle_0", Vector3(-0.58, 0, -2.86))
	_node(root, "Muzzle_1", Vector3(0.58, 0, -2.86))
	return root


func _build_missile_pod() -> Node3D:
	var root: Node3D = _node(null, "MissilePod", Vector3.ZERO)
	_box(root, "Box", Vector3(0.74, 0.74, 1.3), Vector3(0, 0, -0.4), _armour)
	_box(root, "Bracket", Vector3(0.6, 0.2, 0.5), Vector3(-0.6, -0.1, 0.2), _gunmetal)
	_box(root, "Stripe", Vector3(0.76, 0.08, 0.2), Vector3(0, 0.3, -0.85), _amber)
	var index: int = 0
	for y: float in [0.17, -0.17]:
		for x: float in [-0.17, 0.17]:
			_cylinder(root, "Tube_%d" % index, 0.13, 0.12, Vector3(x, y, -1.07), Vector3(90, 0, 0), _dark)
			_node(root, "Muzzle_%d" % index, Vector3(x, y, -1.15))
			index += 1
	return root


func _build_micro_missile() -> Node3D:
	var root: Node3D = _node(null, "MicroMissile", Vector3.ZERO)
	_cylinder(root, "Body", 0.06, 0.5, Vector3(0, 0, 0), Vector3(90, 0, 0), _target_white)
	var nose: MeshInstance3D = _cylinder(root, "Nose", 0.06, 0.16, Vector3(0, 0, -0.33), Vector3(-90, 0, 0), _amber)
	(nose.mesh as CylinderMesh).top_radius = 0.0
	_box(root, "FinHorizontal", Vector3(0.26, 0.012, 0.12), Vector3(0, 0, 0.2), _gunmetal)
	_box(root, "FinVertical", Vector3(0.012, 0.26, 0.12), Vector3(0, 0, 0.2), _gunmetal)
	_cylinder(root, "Nozzle", 0.05, 0.04, Vector3(0, 0, 0.27), Vector3(90, 0, 0), _engine_glow)
	_node(root, "Engine_0", Vector3(0, 0, 0.3))
	return root


func _build_target_dummy() -> Node3D:
	# Radius 1 m; the game scales it to the size in the data.
	var root: Node3D = _node(null, "TargetDummy", Vector3.ZERO)
	var core: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	sphere.material = _target_white
	core.mesh = sphere
	_add(root, core, "Core", Vector3.ZERO)
	for tilt: float in [0.0, 90.0]:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.86
		torus.outer_radius = 1.0
		torus.material = _target_orange
		ring.mesh = torus
		_add(root, ring, "Ring_%d" % int(tilt), Vector3.ZERO)
		ring.rotation_degrees = Vector3(tilt, 0, 0)
	_node(root, "Hitbox_0", Vector3.ZERO)
	return root


func _build_drone() -> Node3D:
	# About 4 m long: a dart with one red sensor eye and one engine.
	var root: Node3D = _node(null, "DroneSwarmer", Vector3.ZERO)
	_box(root, "Body", Vector3(1.0, 0.6, 3.2), Vector3(0, 0, 0), _enemy_hull)
	var nose: MeshInstance3D = _cylinder(root, "Nose", 0.45, 1.2, Vector3(0, 0, -2.2), Vector3(-90, 0, 0), _enemy_panel)
	(nose.mesh as CylinderMesh).top_radius = 0.0
	_box(root, "WingLeft", Vector3(1.6, 0.1, 1.2), Vector3(-1.2, 0, 0.6), _enemy_hull)
	_box(root, "WingRight", Vector3(1.6, 0.1, 1.2), Vector3(1.2, 0, 0.6), _enemy_hull)
	_cylinder(root, "Eye", 0.28, 0.2, Vector3(0, 0.25, -1.5), Vector3(0, 0, 0), _enemy_eye)
	_cylinder(root, "Engine", 0.35, 0.3, Vector3(0, 0, 1.7), Vector3(90, 0, 0), _enemy_eye)
	_node(root, "Hitbox_0", Vector3.ZERO)
	_node(root, "Engine_0", Vector3(0, 0, 1.9))
	_node(root, "Hardpoint_0", Vector3(0, 0, -2.6))
	return root


func _build_interceptor() -> Node3D:
	# About 10 m long: a fighter with swept wings, twin engines and a chin laser.
	var root: Node3D = _node(null, "Interceptor", Vector3.ZERO)
	_box(root, "Fuselage", Vector3(1.6, 1.2, 8.0), Vector3(0, 0, 0), _enemy_hull)
	var nose: MeshInstance3D = _cylinder(root, "Nose", 0.8, 3.0, Vector3(0, 0, -5.4), Vector3(-90, 0, 0), _enemy_panel)
	(nose.mesh as CylinderMesh).top_radius = 0.0
	_box(root, "Canopy", Vector3(0.9, 0.5, 2.0), Vector3(0, 0.75, -1.8), _enemy_eye)
	for side: int in [-1, 1]:
		var suffix: String = "Left" if side < 0 else "Right"
		var wing: MeshInstance3D = _box(root, "Wing" + suffix, Vector3(5.5, 0.18, 2.6), Vector3(3.3 * side, 0, 1.6), _enemy_hull)
		wing.rotation_degrees = Vector3(0, -22.0 * side, 0)
		_box(root, "Tail" + suffix, Vector3(0.14, 1.8, 1.6), Vector3(0.9 * side, 1.1, 3.2), _enemy_panel)
		_cylinder(root, "Engine" + suffix, 0.5, 0.5, Vector3(0.6 * side, 0, 4.1), Vector3(90, 0, 0), _enemy_eye)
		_node(root, "Engine_%d" % (0 if side < 0 else 1), Vector3(0.6 * side, 0, 4.4))
	_cylinder(root, "ChinGun", 0.14, 2.2, Vector3(0, -0.75, -3.4), Vector3(90, 0, 0), _dark)
	_node(root, "Hardpoint_0", Vector3(0, -0.75, -4.6))
	_node(root, "Hitbox_0", Vector3.ZERO)
	return root


func _build_bomber() -> Node3D:
	# About 24 m wingspan: a flying wing with a belly bomb bay and four engines.
	var root: Node3D = _node(null, "Bomber", Vector3.ZERO)
	_box(root, "Wing", Vector3(24.0, 0.9, 7.0), Vector3(0, 0, 0.5), _enemy_hull)
	_box(root, "Centre", Vector3(5.0, 2.2, 11.0), Vector3(0, 0, -0.5), _enemy_hull)
	_box(root, "Belly", Vector3(3.4, 1.2, 6.0), Vector3(0, -1.5, 0), _enemy_panel)
	_box(root, "Cockpit", Vector3(2.4, 0.5, 1.6), Vector3(0, 0.9, -5.2), _enemy_eye)
	var index: int = 0
	for x: float in [-8.0, -4.0, 4.0, 8.0]:
		_cylinder(root, "Nacelle_%d" % index, 0.9, 5.0, Vector3(x, -0.3, 1.5), Vector3(90, 0, 0), _enemy_panel)
		_cylinder(root, "EngineGlow_%d" % index, 0.75, 0.4, Vector3(x, -0.3, 4.1), Vector3(90, 0, 0), _enemy_eye)
		_node(root, "Engine_%d" % index, Vector3(x, -0.3, 4.4))
		index += 1
	_node(root, "Hardpoint_0", Vector3(0, -2.4, 0))
	_node(root, "Hitbox_0", Vector3.ZERO)
	return root


func _build_enemy_bomb() -> Node3D:
	# About 2.4 m long, with a glowing red band so it can be seen falling.
	var root: Node3D = _node(null, "EnemyBomb", Vector3.ZERO)
	_cylinder(root, "Body", 0.45, 1.8, Vector3(0, 0, 0), Vector3(90, 0, 0), _enemy_hull)
	var nose: MeshInstance3D = _cylinder(root, "Nose", 0.45, 0.7, Vector3(0, 0, -1.25), Vector3(-90, 0, 0), _enemy_panel)
	(nose.mesh as CylinderMesh).top_radius = 0.0
	_cylinder(root, "Band", 0.5, 0.35, Vector3(0, 0, -0.3), Vector3(90, 0, 0), _enemy_eye)
	_box(root, "FinHorizontal", Vector3(1.6, 0.06, 0.6), Vector3(0, 0, 0.9), _enemy_panel)
	_box(root, "FinVertical", Vector3(0.06, 1.6, 0.6), Vector3(0, 0, 0.9), _enemy_panel)
	_node(root, "Hitbox_0", Vector3.ZERO)
	_node(root, "Engine_0", Vector3(0, 0, 1.0))
	return root


# --- Helpers ----------------------------------------------------------------

func _make_materials() -> void:
	_gunmetal = _material("Gunmetal", Color(0.4, 0.42, 0.45), 0.55, 0.45)
	_armour = _material("ArmourPlate", Color(0.3, 0.36, 0.3), 0.3, 0.6)
	_dark = _material("DarkSteel", Color(0.13, 0.135, 0.14), 0.4, 0.5)
	_concrete = _material("Concrete", Color(0.42, 0.4, 0.37), 0.0, 0.92)
	_amber = _material("AmberMarking", Color(0.95, 0.55, 0.1), 0.2, 0.6, Color(0.9, 0.45, 0.05))
	_lens = _material("EnergyLens", Color(0.3, 0.9, 1.0), 0.0, 0.2, Color(0.3, 0.9, 1.0))
	_target_white = _material("TargetWhite", Color(0.85, 0.85, 0.82), 0.3, 0.5)
	_target_orange = _material("TargetOrange", Color(1.0, 0.4, 0.05), 0.2, 0.5, Color(1.0, 0.35, 0.05))
	_engine_glow = _material("EngineGlow", Color(1.0, 0.7, 0.3), 0.0, 0.4, Color(1.0, 0.6, 0.2))
	_enemy_hull = _material("EnemyHull", Color(0.1, 0.12, 0.2), 0.5, 0.45)
	_enemy_panel = _material("EnemyPanel", Color(0.5, 0.55, 0.65), 0.4, 0.5)
	_enemy_eye = _material("EnemyEye", Color(1.0, 0.15, 0.1), 0.0, 0.3, Color(1.0, 0.1, 0.05))
	_enemy_eye.emission_energy_multiplier = 4.0


func _material(material_name: String, albedo: Color, metallic: float, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.0
	return material


func _node(parent: Node3D, node_name: String, position: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	_add(parent, node, node_name, position)
	return node


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	_add(parent, instance, node_name, position)
	return instance


## A cylinder along its local Y axis; pass rotation (90, 0, 0) to lay it along Z.
func _cylinder(parent: Node3D, node_name: String, radius: float, length: float, position: Vector3, rotation_deg: Vector3, material: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 24
	mesh.rings = 1
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	_add(parent, instance, node_name, position)
	instance.rotation_degrees = rotation_deg
	return instance


func _add(parent: Node3D, node: Node3D, node_name: String, position: Vector3) -> void:
	node.name = node_name
	node.position = position
	if parent != null:
		parent.add_child(node)


func _export(model_root: Node3D, relative_path: String) -> int:
	var path: String = OUT_DIR.path_join(relative_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_scene(model_root, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	model_root.free()
	if error != OK:
		push_error("Could not export %s (error %d)" % [path, error])
		return 1
	print("  wrote ", path)
	return 0
