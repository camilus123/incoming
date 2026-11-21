class_name TargetDummy
extends CombatTarget
## A static practice target. It shows its remaining shield and hp, blows up
## when destroyed and comes back after a few seconds.

var _data: Dictionary = {}
var _respawn_s: float = 3.0
var _respawn_left_s: float = 0.0
var _visual: Node3D
var _hurtbox: Hurtbox
var _label: Label3D
var _hit_pulse: float = 0.0


## `dummy_data` is one entry of test_range.json; `model_id` an asset ID.
func setup(dummy_data: Dictionary, model_id: String, respawn_s: float) -> void:
	_data = dummy_data
	_respawn_s = respawn_s
	target_radius_m = dummy_data.get("radius_m", 6.0)
	stats = TargetStats.from_data(dummy_data)

	var scene: PackedScene = GameData.assets.load_asset(model_id) as PackedScene
	_visual = scene.instantiate() if scene != null else _fallback_visual()
	_visual.scale = Vector3.ONE * target_radius_m
	add_child(_visual)

	_hurtbox = Hurtbox.create_sphere(self, target_radius_m)
	add_child(_hurtbox)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0007
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0.0, target_radius_m * 1.5, 0.0)
	add_child(_label)
	_refresh_label()


func _process(delta_s: float) -> void:
	super._process(delta_s)
	if _respawn_left_s > 0.0:
		_respawn_left_s -= delta_s
		if _respawn_left_s <= 0.0:
			_respawn()
		return
	if _hit_pulse > 0.0:
		_hit_pulse = maxf(0.0, _hit_pulse - delta_s * 6.0)
		_visual.scale = Vector3.ONE * target_radius_m * (1.0 + 0.12 * _hit_pulse)
	_refresh_label()


func is_alive() -> bool:
	return _respawn_left_s <= 0.0 and super.is_alive()


func apply_damage(info: DamageInfo) -> DamageResult:
	var result: DamageResult = super.apply_damage(info)
	if result != null:
		_hit_pulse = 1.0
	return result


func _on_killed() -> void:
	_respawn_left_s = _respawn_s
	_visual.visible = false
	_label.visible = false
	_hurtbox.set_enabled(false)
	var fx: CombatFx = get_tree().get_first_node_in_group(CombatFx.GROUP) as CombatFx
	if fx != null:
		fx.explosion(global_position, target_radius_m * 2.5, Color(1.0, 0.55, 0.2))


func _respawn() -> void:
	stats = TargetStats.from_data(_data)
	_visual.visible = true
	_visual.scale = Vector3.ONE * target_radius_m
	_label.visible = true
	_hurtbox.set_enabled(true)


func _refresh_label() -> void:
	if stats.max_shield > 0.0:
		_label.text = "%d  +%d" % [ceili(stats.hp), ceili(stats.shield)]
	else:
		_label.text = str(ceili(stats.hp))


func _fallback_visual() -> Node3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = SphereMesh.new()
	return instance
