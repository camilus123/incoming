class_name EnemyProjectile
extends CombatTarget
## A shootable enemy projectile (bomb, later missiles and torpedoes).
##
## It starts with the velocity of the craft that released it, then homes in
## on the turret while accelerating. Shooting it down counts as an intercept;
## if it arrives it damages the turret.

const IMPACT_DISTANCE_M: float = 5.0

var damage: float = 0.0

var _manager: EnemyManager
var _turret: Turret
var _projectile: Dictionary = {}
var _speed_mps: float = 0.0
var _visual: Node3D
var _hurtbox: Hurtbox


## `attack` is the attack entry of the enemy that released the projectile.
func setup(attack: Dictionary, start_velocity: Vector3, attack_damage: float, manager: EnemyManager, turret: Turret) -> void:
	_manager = manager
	_turret = turret
	_projectile = attack.get("projectile", {})
	damage = attack_damage
	name = str(attack.get("id", "projectile"))
	velocity = start_velocity
	_speed_mps = maxf(start_velocity.length(), float(_projectile.get("speed_mps", 60.0)))
	target_radius_m = _projectile.get("hitbox_radius_m", 2.0)
	stats = TargetStats.from_data({"hp": _projectile.get("hp", 20.0)})

	var model_id: String = _projectile.get("model", "")
	var scene: PackedScene = GameData.assets.load_asset(model_id) as PackedScene if not model_id.is_empty() else null
	_visual = scene.instantiate() if scene != null else _fallback_visual()
	add_child(_visual)
	_hurtbox = Hurtbox.create_sphere(self, target_radius_m, Layers.PHYSICS_ENEMY_PROJECTILE)
	add_child(_hurtbox)


func _process(delta_s: float) -> void:
	super._process(delta_s)
	if stats.is_dead():
		return
	var to_turret: Vector3 = _turret.get_hit_point() - global_position
	var distance: float = to_turret.length()
	_hurtbox.apply_distance_assist(distance)
	if distance <= IMPACT_DISTANCE_M or global_position.y <= 0.5:
		_impact(distance)
		return
	_speed_mps = minf(_speed_mps + float(_projectile.get("acceleration_mps2", 20.0)) * delta_s, _projectile.get("max_speed_mps", 150.0))
	# Blend from the release velocity into a straight run at the turret.
	var desired: Vector3 = to_turret / distance * _speed_mps
	velocity = velocity.lerp(desired, 1.0 - exp(-1.5 * delta_s))
	global_position += velocity * delta_s
	var direction: Vector3 = velocity.normalized()
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(direction, up), global_position)


func get_hit_radius() -> float:
	return _hurtbox.radius_m


func _impact(distance_to_turret: float) -> void:
	var blast_radius_m: float = _projectile.get("blast_radius_m", 10.0)
	if distance_to_turret <= blast_radius_m:
		_turret.take_damage(damage)
	_explode(blast_radius_m)
	_manager.notify_projectile_gone(self)
	queue_free()


func _on_killed() -> void:
	_explode(float(_projectile.get("blast_radius_m", 10.0)) * 0.6)
	EventBus.enemy_projectile_intercepted.emit(StringName(name))
	_manager.notify_projectile_gone(self)
	queue_free()


func _explode(radius_m: float) -> void:
	var fx: CombatFx = _manager.get_fx()
	if fx != null:
		fx.explosion(global_position, radius_m, Color(1.0, 0.5, 0.15))


func _fallback_visual() -> Node3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	instance.mesh = mesh
	return instance
