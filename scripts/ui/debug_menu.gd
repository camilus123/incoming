class_name DebugMenu
extends CanvasLayer
## Developer menu, debug builds only (spec 14). F4 opens it:
## give credits, skip the stage, spawn an enemy, god mode, show hit shapes,
## show the stats overlay.
##
## It only calls what the game already offers, plus two switches other
## scripts read: `show_stats` (the HUD read-out) and `show_hitboxes`.

const CANVAS_LAYER: int = 50
const TOGGLE_KEY: Key = KEY_F4
const SPAWN_DISTANCE_M: float = 1400.0

## The HUD draws its developer read-out while this is on (F1 toggles it too).
static var show_stats: bool = false
## Hit shapes are drawn as translucent spheres while this is on.
static var show_hitboxes: bool = false

var _panel: PanelContainer
var _enemy_picker: OptionButton
var _enemy_ids: Array = []
var _hitbox_mesh: SphereMesh
var _hitbox_material: StandardMaterial3D
var _markers: Dictionary = {}  # Hurtbox -> MeshInstance3D


func _ready() -> void:
	layer = CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	show_stats = OS.get_cmdline_user_args().has("--debug-hud")
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.visible = false
	_panel.position = Vector2(40.0, 120.0)
	_panel.custom_minimum_size = Vector2(340.0, 0.0)
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	column.add_child(UiTheme.label("DEBUG (F4)", 20, UiTheme.COLOR_WARN))
	column.add_child(UiTheme.button("+1,000 credits", func() -> void: GameState.add_credits(1000)))
	column.add_child(UiTheme.button("+10,000 credits", func() -> void: GameState.add_credits(10000)))
	column.add_child(UiTheme.button("Skip stage", _skip_stage))
	column.add_child(_toggle("God mode", func() -> bool: return _turret() != null and _turret().invulnerable, func(on: bool) -> void:
		if _turret() != null:
			_turret().invulnerable = on))
	column.add_child(_toggle("Show hit shapes", func() -> bool: return show_hitboxes, func(on: bool) -> void: show_hitboxes = on))
	column.add_child(_toggle("Stats overlay (F1)", func() -> bool: return show_stats, func(on: bool) -> void: show_stats = on))
	_enemy_picker = OptionButton.new()
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	_enemy_ids = enemies.keys()
	_enemy_ids.sort()
	for id: String in _enemy_ids:
		_enemy_picker.add_item(str(enemies[id].get("display_name", id)))
	column.add_child(_enemy_picker)
	column.add_child(UiTheme.button("Spawn enemy", _spawn_enemy))

	_hitbox_mesh = SphereMesh.new()
	_hitbox_mesh.radius = 1.0
	_hitbox_mesh.height = 2.0
	_hitbox_mesh.radial_segments = 16
	_hitbox_mesh.rings = 8
	_hitbox_material = StandardMaterial3D.new()
	_hitbox_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hitbox_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hitbox_material.albedo_color = Color(0.2, 1.0, 0.4, 0.22)
	_hitbox_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hitbox_mesh.material = _hitbox_material


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == TOGGLE_KEY:
		_panel.visible = not _panel.visible
		# The menu needs the pointer; the game takes it back when the menu closes.
		if _panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not get_tree().paused and _stages() != null and _stages().state != StageManager.State.SHOP:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F1:
		show_stats = not show_stats


func _process(_delta_s: float) -> void:
	if not show_hitboxes and _markers.is_empty():
		return
	# One sphere per live hit shape, sized to its current (distance-assisted) radius.
	var seen: Dictionary = {}
	if show_hitboxes:
		for target: CombatTarget in CombatTarget.registry:
			if not target.is_alive():
				continue
			for child: Node in target.get_children():
				var hurtbox: Hurtbox = child as Hurtbox
				if hurtbox == null or hurtbox.radius_m <= 0.0:
					continue
				seen[hurtbox] = true
				var marker: MeshInstance3D = _markers.get(hurtbox)
				if marker == null:
					marker = MeshInstance3D.new()
					marker.mesh = _hitbox_mesh
					marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					marker.top_level = true
					hurtbox.add_child(marker)
					_markers[hurtbox] = marker
				marker.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * hurtbox.radius_m), hurtbox.global_position)
	for hurtbox: Variant in _markers.keys():
		if not seen.has(hurtbox):
			var marker: MeshInstance3D = _markers[hurtbox]
			if is_instance_valid(marker):
				marker.queue_free()
			_markers.erase(hurtbox)


func _toggle(text: String, read: Callable, write: Callable) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.button_pressed = read.call()
	check.toggled.connect(func(on: bool) -> void: write.call(on))
	_panel.visibility_changed.connect(func() -> void: check.set_pressed_no_signal(read.call()))
	return check


func _skip_stage() -> void:
	var stages: StageManager = _stages()
	if stages != null:
		stages.debug_skip_stage()


func _spawn_enemy() -> void:
	var manager: EnemyManager = get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	var turret: Turret = _turret()
	if manager == null or turret == null or _enemy_ids.is_empty():
		return
	var aim: Transform3D = turret.get_aim_transform()
	# Where the player is looking, but never below 15 degrees.
	var direction: Vector3 = -aim.basis.z
	direction.y = maxf(direction.y, 0.26)
	manager.spawn_enemy(str(_enemy_ids[_enemy_picker.selected]), aim.origin + direction.normalized() * SPAWN_DISTANCE_M)


func _turret() -> Turret:
	return get_tree().get_first_node_in_group(Turret.GROUP) as Turret


func _stages() -> StageManager:
	return get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
