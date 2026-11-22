class_name WeakPoint
extends CombatTarget
## A destructible subsystem of a large enemy: a shield generator, a turret, a
## hangar bay, an engine. It is a target of its own (it can be shot and locked
## on to) attached to its owner. Destroying it triggers the effect in its data,
## and the effect of its group once every member of the group is gone.
##
## Data (an entry of the enemy's "weak_points" list):
##   id, hp, radius_m, group
##   socket   name of a node in the model (e.g. "WeakPoint_Hangar_0"), or
##   offset   [x, y, z] in the enemy's local space
##   effect   { disable_shield, disable_spawn, disable_attacks, speed_mult, damage_to_owner, message }

var data: Dictionary = {}

var _enemy: Enemy
var _hurtbox: Hurtbox
var _marker: MeshInstance3D


func setup(weak_point_data: Dictionary, owner_enemy: Enemy, hp_scale: float) -> void:
	data = weak_point_data
	_enemy = owner_enemy
	name = str(weak_point_data.get("id", "weak_point"))
	target_radius_m = weak_point_data.get("radius_m", 4.0)
	stats = TargetStats.from_data({"hp": float(weak_point_data.get("hp", 100.0)) * hp_scale, "armour": weak_point_data.get("armour", 0.0)})
	_hurtbox = Hurtbox.create_sphere(self, target_radius_m)
	add_child(_hurtbox)
	# A glowing core so the player can see what to shoot.
	_marker = owner_enemy.get_manager().make_weak_point_marker(target_radius_m * 0.55)
	add_child(_marker)


func _process(delta_s: float) -> void:
	super._process(delta_s)
	if not stats.is_dead() and is_instance_valid(_enemy):
		_hurtbox.set_enabled(_enemy.is_alive())
		_hurtbox.apply_distance_assist(global_position.distance_to(_enemy.get_turret_point()))


func is_alive() -> bool:
	return super.is_alive() and is_instance_valid(_enemy) and _enemy.is_alive()


func get_hit_radius() -> float:
	return _hurtbox.radius_m


func get_hurtbox() -> Hurtbox:
	return _hurtbox


func _on_killed() -> void:
	var fx: CombatFx = _enemy.get_manager().get_fx()
	if fx != null:
		fx.explosion(global_position, target_radius_m * 3.0, Color(1.0, 0.7, 0.3))
	_enemy.on_weak_point_destroyed(self)
	queue_free()
