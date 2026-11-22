class_name FrontierEnvironment
extends Node3D
## The frontier world around the turret: sky, sun, fog, terrain and the bodies
## in the sky. Everything is built from `data/config/environments.json`.
##
## A stage chooses a time of day ("day", "dusk", "night", or any other entry
## of "times"); the environment switches when the stage starts. The quality
## switches (shadows, GI, SSAO, SSR, volumetric fog, glow) follow the active
## graphics preset.
##
## Command-line option (after `++`): `--time=<id>` forces a time of day.

const GROUP: StringName = &"frontier_environment"
const TERRAIN_SHADER: String = "vfx.shader.terrain"
const BODY_SHADER: String = "vfx.shader.sky_body"
const RING_SHADER: String = "vfx.shader.sky_ring"
## Sky bodies sit this far away; they are drawn without fog, so only their
## apparent size matters.
const BODY_DISTANCE_M: float = 17000.0
const TERRAIN_RINGS: int = 84
const TERRAIN_SEGMENTS: int = 192
const TERRAIN_INNER_RADIUS_M: float = 10.0
const STAR_COUNT: int = 2600
const STAR_SHADER: String = "vfx.shader.stars"
const STAR_DISTANCE_M: float = 26000.0
const TONEMAPPERS: Dictionary = {
	"linear": Environment.TONE_MAPPER_LINEAR,
	"reinhard": Environment.TONE_MAPPER_REINHARDT,
	"filmic": Environment.TONE_MAPPER_FILMIC,
	"aces": Environment.TONE_MAPPER_ACES,
	"agx": Environment.TONE_MAPPER_AGX,
}
const SHADOW_DISTANCE_M: Dictionary = {"off": 0.0, "low": 60.0, "medium": 120.0, "high": 250.0, "ultra": 450.0}

var _config: Dictionary = {}
var _environment: Environment
var _sky_material: PhysicalSkyMaterial
var _sun: DirectionalLight3D
var _terrain: MeshInstance3D
var _body_materials: Array[ShaderMaterial] = []
var _ring_materials: Array[ShaderMaterial] = []
var _stars: MeshInstance3D
var _star_material: ShaderMaterial
var _time_id: String = ""
var _forced_time: String = ""
var _dune_noise: FastNoiseLite = FastNoiseLite.new()
var _mountain_noise: FastNoiseLite = FastNoiseLite.new()


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_config = GameData.loader.get_config("environments")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--time="):
			_forced_time = argument.trim_prefix("--time=")
	_build_environment()
	_build_terrain()
	_build_sky_bodies()
	_build_stars()
	apply_time(_config.get("default_time", "day"))
	_apply_graphics()
	Graphics.changed.connect(_apply_graphics)
	EventBus.stage_started.connect(_on_stage_started)
	EventBus.data_reloaded.connect(_on_data_reloaded)


## The Environment resource in use (the camera rig copies it for the viewmodel).
func get_environment() -> Environment:
	return _environment


## Flat ambient light for the turret and guns, which are drawn by their own
## camera without the sky: `{ "color": Color, "energy": float }`.
func get_turret_ambient() -> Dictionary:
	var ambient: Dictionary = (_config.get("times", {}) as Dictionary).get(_time_id, {}).get("turret_ambient", {})
	return {"color": _color(ambient.get("color", [0.6, 0.65, 0.75])), "energy": float(ambient.get("energy", 0.8))}


## Id of the time of day currently shown.
func get_time_id() -> String:
	return _time_id


## Switches sky, sun and fog to one of the entries of "times".
## An unknown id falls back to the default time.
func apply_time(time_id: String) -> void:
	var times: Dictionary = _config.get("times", {})
	if not _forced_time.is_empty() and times.has(_forced_time):
		time_id = _forced_time
	if not times.has(time_id):
		time_id = _config.get("default_time", "day")
	if not times.has(time_id):
		return
	_time_id = time_id
	var time: Dictionary = times[time_id]

	var sun: Dictionary = time["sun"]
	var to_sun: Vector3 = TurretAim.direction_from(sun.get("azimuth_deg", 0.0), sun.get("elevation_deg", 45.0))
	var up: Vector3 = Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.RIGHT
	_sun.basis = Basis.looking_at(-to_sun, up)
	_sun.light_color = _color(sun.get("color", [1.0, 1.0, 1.0]))
	_sun.light_energy = sun.get("energy", 1.0)

	var sky: Dictionary = time["sky"]
	_sky_material.rayleigh_coefficient = sky.get("rayleigh", 2.0)
	_sky_material.rayleigh_color = _color(sky.get("rayleigh_color", [0.3, 0.4, 0.7]))
	_sky_material.mie_coefficient = sky.get("mie", 0.005)
	_sky_material.mie_color = _color(sky.get("mie_color", [0.7, 0.6, 0.5]))
	_sky_material.turbidity = sky.get("turbidity", 10.0)
	_sky_material.energy_multiplier = sky.get("energy", 1.0)
	_sky_material.ground_color = _color(sky.get("ground_color", [0.3, 0.25, 0.2]))
	var stars: float = sky.get("stars", 0.0)
	_stars.visible = stars > 0.0
	_star_material.set_shader_parameter(&"brightness", stars)

	_environment.ambient_light_energy = time.get("ambient_energy", 1.0)
	_environment.tonemap_exposure = time.get("exposure", 1.0)
	var fog: Dictionary = time["fog"]
	_environment.fog_density = fog.get("density", 0.00005)
	_environment.fog_light_color = _color(fog.get("color", [0.8, 0.7, 0.6]))
	_environment.fog_sky_affect = fog.get("sky_affect", 0.2)
	_environment.volumetric_fog_density = fog.get("volumetric_density", 0.001)
	_environment.volumetric_fog_albedo = _color(fog.get("volumetric_albedo", [1.0, 1.0, 1.0]))

	var body_light: Dictionary = time.get("sky_body_light", {})
	var light_direction: Vector3 = TurretAim.direction_from(body_light.get("azimuth_deg", 0.0), body_light.get("elevation_deg", 30.0))
	var brightness: float = time.get("sky_body_brightness", 1.0)
	var dark_side: float = time.get("sky_body_dark_side", 0.0)
	for material: ShaderMaterial in _body_materials:
		material.set_shader_parameter(&"light_direction", light_direction)
		material.set_shader_parameter(&"brightness", brightness)
		material.set_shader_parameter(&"dark_side", dark_side)
	for material: ShaderMaterial in _ring_materials:
		material.set_shader_parameter(&"brightness", brightness)
		material.set_shader_parameter(&"opacity", lerpf(0.45, 1.0, dark_side))
	EventBus.environment_changed.emit()


## Terrain height above the turret's ground level at a point of the world.
func get_height(x: float, z: float) -> float:
	var terrain: Dictionary = _config.get("terrain", {})
	var distance: float = Vector2(x, z).length()
	var flat_m: float = terrain.get("flat_radius_m", 1500.0)
	var dunes: float = (_dune_noise.get_noise_2d(x, z) * 0.5 + 0.5) * float(terrain.get("dune_height_m", 5.0)) \
			* smoothstep(flat_m * 0.2, flat_m, distance)
	var ridges: float = pow(_mountain_noise.get_noise_2d(x, z) * 0.5 + 0.5, 1.5) * float(terrain.get("mountain_height_m", 1500.0)) \
			* smoothstep(float(terrain.get("mountain_start_m", 4200.0)), float(terrain.get("mountain_full_m", 9500.0)), distance)
	return dunes + ridges


func _on_stage_started(_stage: int) -> void:
	var stages: StageManager = get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
	if stages != null:
		apply_time(stages.stage_data.get("time_of_day", _config.get("default_time", "day")))


func _on_data_reloaded(_report: DataReport) -> void:
	# Colours and angles reload live; terrain shape and sky bodies need a restart.
	_config = GameData.loader.get_config("environments")
	_environment.tonemap_mode = TONEMAPPERS.get(_config.get("tonemap", "agx"), Environment.TONE_MAPPER_AGX)
	apply_time(_time_id)


func _apply_graphics() -> void:
	var shadows: String = Graphics.get_value("shadows", "high")
	_sun.shadow_enabled = shadows != "off"
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if shadows == "low" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = maxf(float(SHADOW_DISTANCE_M.get(shadows, 120.0)), 1.0)
	var gi: String = Graphics.get_value("gi", "off")
	_environment.ssil_enabled = gi == "ssil"
	_environment.sdfgi_enabled = gi == "sdfgi"
	_environment.ssao_enabled = Graphics.get_value("ssao", true)
	_environment.ssr_enabled = Graphics.get_value("ssr", false)
	_environment.volumetric_fog_enabled = Graphics.get_value("volumetric_fog", false)
	_environment.glow_enabled = Graphics.get_value("glow", true)
	EventBus.environment_changed.emit()


func _build_environment() -> void:
	_sky_material = PhysicalSkyMaterial.new()
	_sky_material.sun_disk_scale = 1.4
	var sky: Sky = Sky.new()
	sky.sky_material = _sky_material

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = TONEMAPPERS.get(_config.get("tonemap", "agx"), Environment.TONE_MAPPER_AGX)
	_environment.tonemap_white = 6.0
	_environment.glow_intensity = 0.7
	_environment.glow_bloom = 0.05
	_environment.glow_hdr_threshold = 1.0
	_environment.fog_enabled = true
	_environment.fog_aerial_perspective = 0.4
	_environment.volumetric_fog_length = 500.0
	_environment.volumetric_fog_anisotropy = 0.6
	_environment.ssao_radius = 2.0
	_environment.ssao_intensity = 1.6
	_environment.ssr_max_steps = 48
	_environment.sdfgi_cascades = 4
	_environment.sdfgi_min_cell_size = 1.0

	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = _environment
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	# The viewmodel camera only sees layer 2, so the sun must light both layers.
	_sun.layers = Layers.RENDER_WORLD | Layers.RENDER_VIEWMODEL
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_split_1 = 0.06
	_sun.directional_shadow_split_2 = 0.18
	_sun.directional_shadow_split_3 = 0.45
	_sun.directional_shadow_fade_start = 0.85
	add_child(_sun)


func _build_terrain() -> void:
	var terrain: Dictionary = _config.get("terrain", {})
	var seed_value: int = terrain.get("seed", 11)
	_dune_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_dune_noise.seed = seed_value
	_dune_noise.frequency = 1.0 / 260.0
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain_noise.seed = seed_value + 1
	_mountain_noise.frequency = 1.0 / 6500.0
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.fractal_octaves = 4

	# A disc of rings that get wider with distance: fine near the turret,
	# coarse at the mountains.
	var radius_m: float = terrain.get("radius_m", 16000.0)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	tangents.append_array([1.0, 0.0, 0.0, 1.0])
	for ring: int in TERRAIN_RINGS:
		var ring_radius: float = TERRAIN_INNER_RADIUS_M * pow(radius_m / TERRAIN_INNER_RADIUS_M, float(ring) / float(TERRAIN_RINGS - 1))
		var step_m: float = maxf(3.0, ring_radius * 0.03)
		for segment: int in TERRAIN_SEGMENTS:
			var angle: float = TAU * float(segment) / float(TERRAIN_SEGMENTS)
			var x: float = cos(angle) * ring_radius
			var z: float = sin(angle) * ring_radius
			vertices.append(Vector3(x, get_height(x, z), z))
			var slope_x: float = get_height(x + step_m, z) - get_height(x - step_m, z)
			var slope_z: float = get_height(x, z + step_m) - get_height(x, z - step_m)
			normals.append(Vector3(-slope_x, 2.0 * step_m, -slope_z).normalized())
			tangents.append_array([1.0, 0.0, 0.0, 1.0])
	for segment: int in TERRAIN_SEGMENTS:
		var next_segment: int = (segment + 1) % TERRAIN_SEGMENTS
		indices.append_array([0, 1 + segment, 1 + next_segment])
		for ring: int in TERRAIN_RINGS - 1:
			var inner: int = 1 + ring * TERRAIN_SEGMENTS
			var outer: int = inner + TERRAIN_SEGMENTS
			indices.append_array([inner + segment, outer + segment, outer + next_segment])
			indices.append_array([inner + segment, outer + next_segment, inner + next_segment])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var detail: FastNoiseLite = FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.seed = seed_value + 2
	detail.frequency = 0.012
	detail.fractal_octaves = 5
	var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
	noise_texture.width = 512
	noise_texture.height = 512
	noise_texture.seamless = true
	noise_texture.generate_mipmaps = true
	noise_texture.noise = detail
	var normal_texture: NoiseTexture2D = noise_texture.duplicate()
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 6.0

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GameData.assets.load_asset(TERRAIN_SHADER) as Shader
	material.set_shader_parameter(&"sand_color", _color(terrain.get("sand_color", [0.55, 0.4, 0.28])))
	material.set_shader_parameter(&"rock_color", _color(terrain.get("rock_color", [0.3, 0.24, 0.2])))
	material.set_shader_parameter(&"noise_texture", noise_texture)
	material.set_shader_parameter(&"detail_normal", normal_texture)
	mesh.surface_set_material(0, material)

	_terrain = MeshInstance3D.new()
	_terrain.name = "Terrain"
	_terrain.mesh = mesh
	_terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain.layers = Layers.RENDER_WORLD
	add_child(_terrain)


func _build_sky_bodies() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	for body: Dictionary in _config.get("sky_bodies", []):
		var direction: Vector3 = TurretAim.direction_from(body.get("azimuth_deg", 0.0), body.get("elevation_deg", 40.0))
		var radius_m: float = tan(deg_to_rad(float(body.get("angular_diameter_deg", 5.0)) * 0.5)) * BODY_DISTANCE_M
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GameData.assets.load_asset(BODY_SHADER) as Shader
		material.set_shader_parameter(&"color_a", _color(body.get("color_a", [0.8, 0.8, 0.8])))
		material.set_shader_parameter(&"color_b", _color(body.get("color_b", [0.5, 0.5, 0.5])))
		material.set_shader_parameter(&"bands", body.get("bands", 0.0))
		_body_materials.append(material)

		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = str(body.get("id", "SkyBody"))
		instance.mesh = sphere
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.layers = Layers.RENDER_WORLD
		var ring: Dictionary = body.get("ring", {})
		# Tilted around the line of sight, so bands and ring show as slanted ellipses.
		var sight: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
		var tilt: Basis = Basis(sight, deg_to_rad(float(body.get("tilt_deg", ring.get("tilt_deg", 0.0)))))
		instance.transform = Transform3D(tilt.scaled(Vector3.ONE * radius_m), direction * BODY_DISTANCE_M)
		add_child(instance)
		if ring.is_empty():
			continue
		var outer: float = maxf(float(ring.get("outer", 2.2)), 1.01)
		var ring_material: ShaderMaterial = ShaderMaterial.new()
		ring_material.shader = GameData.assets.load_asset(RING_SHADER) as Shader
		ring_material.render_priority = 1
		ring_material.set_shader_parameter(&"color", _color(ring.get("color", [0.8, 0.7, 0.6])))
		ring_material.set_shader_parameter(&"inner", clampf(float(ring.get("inner", 1.3)) / outer, 0.0, 0.99))
		ring_material.set_shader_parameter(&"planet_radius", 1.0 / outer)
		_ring_materials.append(ring_material)
		var ring_instance: MeshInstance3D = MeshInstance3D.new()
		ring_instance.name = "%sRing" % instance.name
		ring_instance.mesh = plane
		ring_instance.material_override = ring_material
		ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_instance.layers = Layers.RENDER_WORLD
		ring_instance.transform = Transform3D(tilt.scaled(Vector3.ONE * radius_m * outer), direction * BODY_DISTANCE_M)
		add_child(ring_instance)


func _build_stars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(_config.get("terrain", {}).get("seed", 11))
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var sizes: PackedVector2Array = PackedVector2Array()
	for star: int in STAR_COUNT:
		# Uniform over the upper hemisphere and a little below the horizon.
		var height: float = rng.randf_range(-0.1, 1.0)
		var angle: float = rng.randf() * TAU
		var flat: float = sqrt(1.0 - height * height)
		vertices.append(Vector3(cos(angle) * flat, height, sin(angle) * flat) * STAR_DISTANCE_M)
		var strength: float = pow(rng.randf(), 4.0)
		var tint: Color = Color(1.0, 0.9, 0.78).lerp(Color(0.75, 0.86, 1.0), rng.randf())
		colors.append(tint * (0.25 + 1.6 * strength))
		sizes.append(Vector2(1.6 + 2.4 * strength, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = sizes
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	_star_material = ShaderMaterial.new()
	_star_material.shader = GameData.assets.load_asset(STAR_SHADER) as Shader
	_star_material.render_priority = -1
	mesh.surface_set_material(0, _star_material)
	_stars = MeshInstance3D.new()
	_stars.name = "Stars"
	_stars.mesh = mesh
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.layers = Layers.RENDER_WORLD
	add_child(_stars)
	get_tree().root.size_changed.connect(_sync_star_size)
	_sync_star_size()


func _sync_star_size() -> void:
	_star_material.set_shader_parameter(&"point_scale", float(get_tree().root.size.y) / 1080.0)


static func _color(values: Array) -> Color:
	return Color(values[0], values[1], values[2])
