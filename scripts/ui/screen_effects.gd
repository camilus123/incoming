class_name ScreenEffects
extends CanvasLayer
## Lens effects over the finished 3D picture and under the HUD: chromatic
## aberration on hull hits and near explosions, a refraction ripple when the
## shield is hit, and lens dirt that lights up on big explosions.
##
## The full-screen rectangle is only visible while an effect is running, so
## the screen copy it needs costs nothing the rest of the time. Switched off
## by the graphics preset (`screen_effects`) or the player's setting.

const SHADER_ASSET: String = "vfx.shader.screen_effects"
## Above the viewmodel overlay (1), below the HUD (10).
const CANVAS_LAYER: int = 5
const ABERRATION_DECAY_PER_S: float = 3.5
const RIPPLE_S: float = 0.6
const DIRT_DECAY_PER_S: float = 1.6

var _rect: ColorRect
var _material: ShaderMaterial
var _aberration: float = 0.0
var _ripple_left_s: float = 0.0
var _ripple_strength: float = 0.0
var _dirt: float = 0.0
var _enabled: bool = true


func _ready() -> void:
	layer = CANVAS_LAYER
	_material = ShaderMaterial.new()
	_material.shader = GameData.assets.load_asset(SHADER_ASSET) as Shader
	_rect = ColorRect.new()
	_rect.name = "Lens"
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)
	EventBus.shield_hit.connect(_on_shield_hit)
	EventBus.hull_damaged.connect(_on_hull_damaged)
	EventBus.explosion.connect(_on_explosion)
	Graphics.changed.connect(_update_enabled)
	UserSettings.changed.connect(func(_key: String) -> void: _update_enabled())
	_update_enabled()


func _process(delta_s: float) -> void:
	_aberration = maxf(0.0, _aberration - ABERRATION_DECAY_PER_S * delta_s)
	_ripple_left_s = maxf(0.0, _ripple_left_s - delta_s)
	_dirt = maxf(0.0, _dirt - DIRT_DECAY_PER_S * delta_s)
	var active: bool = _enabled and (_aberration > 0.01 or _ripple_left_s > 0.0 or _dirt > 0.01)
	_rect.visible = active
	if not active:
		return
	var window: Vector2 = get_viewport().get_visible_rect().size
	var ripple_progress: float = 1.0 - _ripple_left_s / RIPPLE_S
	_material.set_shader_parameter(&"aspect", window.x / maxf(window.y, 1.0))
	_material.set_shader_parameter(&"aberration", _aberration)
	_material.set_shader_parameter(&"ripple", _ripple_strength * (1.0 - ripple_progress) if _ripple_left_s > 0.0 else 0.0)
	_material.set_shader_parameter(&"ripple_phase", ripple_progress)
	_material.set_shader_parameter(&"dirt", _dirt)


func _update_enabled() -> void:
	_enabled = bool(Graphics.get_value("screen_effects", true)) and bool(UserSettings.get_value(UserSettings.SCREEN_EFFECTS))


func _on_shield_hit(amount: float, _remaining: float) -> void:
	_ripple_strength = clampf(amount / 20.0, 0.25, 1.0)
	_ripple_left_s = RIPPLE_S


func _on_hull_damaged(amount: float, _remaining: float) -> void:
	_aberration = minf(1.0, _aberration + clampf(amount / 25.0, 0.3, 1.0))


func _on_explosion(at: Vector3, radius_m: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(at):
		return
	# How big the blast looks from here: its radius over its distance.
	var apparent: float = radius_m / maxf(camera.global_position.distance_to(at), 1.0)
	if apparent < 0.04:
		return
	_dirt = minf(0.6, _dirt + apparent * 2.0)
	_aberration = minf(1.0, _aberration + apparent * 1.5)
