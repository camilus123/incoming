class_name FirstPersonRig
extends CameraRig
## First-person camera at the turret's sighting position.
##
## Two cameras share one transform:
## - the world camera draws everything except the viewmodel layer;
## - the viewmodel camera draws only the turret and guns into a transparent
##   SubViewport that is laid over the world. This gives the guns their own
##   field of view and guarantees they never clip into the world.

const RECOIL_RECOVER_PER_S: float = 14.0
const SHAKE_DECAY_PER_S: float = 2.2
const SHAKE_FREQUENCY_HZ: float = 26.0
const VIEWMODEL_CANVAS_LAYER: int = 1

var _camera: Camera3D
var _viewmodel_camera: Camera3D
var _viewmodel_viewport: SubViewport
var _fov_horizontal_default_deg: float = 90.0
var _shake_max_deg: float = 1.2
var _recoil_deg: float = 0.0
var _trauma: float = 0.0
var _time_s: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0

	_camera = Camera3D.new()
	_camera.name = "WorldCamera"
	_camera.near = 0.2
	_camera.far = 20000.0
	_camera.cull_mask = 0xFFFFF & ~Layers.RENDER_VIEWMODEL
	add_child(_camera)
	_camera.make_current()

	_viewmodel_viewport = SubViewport.new()
	_viewmodel_viewport.name = "ViewmodelViewport"
	_viewmodel_viewport.transparent_bg = true
	_viewmodel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewmodel_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewmodel_viewport)

	_viewmodel_camera = Camera3D.new()
	_viewmodel_camera.name = "ViewmodelCamera"
	_viewmodel_camera.near = 0.05
	_viewmodel_camera.far = 60.0
	_viewmodel_camera.cull_mask = Layers.RENDER_VIEWMODEL
	_viewmodel_viewport.add_child(_viewmodel_camera)
	_viewmodel_camera.make_current()

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ViewmodelOverlay"
	layer.layer = VIEWMODEL_CANVAS_LAYER
	add_child(layer)
	var overlay: TextureRect = TextureRect.new()
	overlay.texture = _viewmodel_viewport.get_texture()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	get_tree().root.size_changed.connect(_sync_viewport_size)
	_sync_viewport_size()
	_setup_viewmodel_environment.call_deferred()
	UserSettings.changed.connect(_on_setting_changed)


func configure(camera_config: Dictionary) -> void:
	_fov_horizontal_default_deg = camera_config.get("fov_horizontal_deg_at_16_9", 90.0)
	_shake_max_deg = camera_config.get("screen_shake_max_deg", 1.2)
	_viewmodel_camera.fov = camera_config.get("viewmodel_fov_deg", 55.0)
	_apply_fov()


func update_rig(aim_transform: Transform3D, delta_s: float) -> void:
	_time_s += delta_s
	_recoil_deg = lerpf(_recoil_deg, 0.0, 1.0 - exp(-RECOIL_RECOVER_PER_S * delta_s))
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY_PER_S * delta_s)

	var shake_strength: float = _trauma * _trauma * _shake_max_deg * float(UserSettings.get_value(UserSettings.SCREEN_SHAKE))
	var sample: float = _time_s * SHAKE_FREQUENCY_HZ
	var offset: Vector3 = Vector3(
		deg_to_rad(_recoil_deg + _noise.get_noise_2d(sample, 0.0) * shake_strength),
		deg_to_rad(_noise.get_noise_2d(sample, 37.0) * shake_strength),
		deg_to_rad(_noise.get_noise_2d(sample, 91.0) * shake_strength * 0.5))
	var view: Transform3D = Transform3D(aim_transform.basis * Basis.from_euler(offset), aim_transform.origin)
	_camera.global_transform = view
	_viewmodel_camera.global_transform = view


func get_camera() -> Camera3D:
	return _camera


func get_viewmodel_layers() -> int:
	return Layers.RENDER_VIEWMODEL


func viewmodel_to_world(world_position: Vector3) -> Vector3:
	# Same screen position and depth, re-projected from the viewmodel FOV to the world FOV.
	var local: Vector3 = _camera.global_transform.affine_inverse() * world_position
	var ratio: float = tan(deg_to_rad(_camera.fov) * 0.5) / tan(deg_to_rad(_viewmodel_camera.fov) * 0.5)
	return _camera.global_transform * Vector3(local.x * ratio, local.y * ratio, local.z)


func get_vertical_fov_deg() -> float:
	return _camera.fov


func add_recoil(pitch_deg: float) -> void:
	_recoil_deg += pitch_deg


func add_shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## Converts a horizontal FOV defined at 16:9 into the vertical FOV Godot uses.
## Wider screens keep this vertical FOV and therefore see more to the sides.
static func vertical_fov_from_horizontal_16_9(horizontal_deg: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_deg) * 0.5) * 9.0 / 16.0))


func _apply_fov() -> void:
	var horizontal: float = UserSettings.get_float_or(UserSettings.FOV_HORIZONTAL_DEG, _fov_horizontal_default_deg)
	_camera.fov = vertical_fov_from_horizontal_16_9(horizontal)


func _on_setting_changed(key: String) -> void:
	if key == UserSettings.FOV_HORIZONTAL_DEG:
		_apply_fov()


func _sync_viewport_size() -> void:
	var window_size: Vector2i = get_tree().root.size
	_viewmodel_viewport.size = Vector2i(maxi(2, window_size.x), maxi(2, window_size.y))


func _setup_viewmodel_environment() -> void:
	# Light the guns like the world, but keep the background transparent.
	var world_environment: Environment = get_world_3d().environment
	if world_environment == null:
		return
	var environment: Environment = world_environment.duplicate()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false
	environment.ssr_enabled = false
	environment.sdfgi_enabled = false
	_viewmodel_camera.environment = environment
