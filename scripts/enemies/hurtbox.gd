class_name Hurtbox
extends Area3D
## A simple collision shape that weapons can hit. It forwards hits to the
## [CombatTarget] that owns it. Hit shapes are never the render mesh.

## The target that takes the damage.
var target: CombatTarget
## Multiplier for hits on this shape (weak points use more than 1).
var damage_multiplier: float = 1.0
## Physics layer the shape sits on while enabled.
var layer_bits: int = Layers.PHYSICS_ENEMY
## Current hit radius (spherical hurtboxes), including the distance assist.
var radius_m: float = 0.0

var _base_radius_m: float = 0.0
var _sphere: SphereShape3D


func _init() -> void:
	collision_layer = Layers.PHYSICS_ENEMY
	collision_mask = 0
	monitoring = false
	monitorable = true


## Creates a spherical hurtbox for `owner_target`.
static func create_sphere(owner_target: CombatTarget, radius_m: float, layer: int = Layers.PHYSICS_ENEMY) -> Hurtbox:
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.target = owner_target
	hurtbox.layer_bits = layer
	hurtbox.collision_layer = layer
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius_m
	hurtbox._sphere = shape
	hurtbox._base_radius_m = radius_m
	hurtbox.radius_m = radius_m
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	hurtbox.add_child(collision)
	return hurtbox


## A shot along this ray struck this shape. If the shape belongs to an enemy
## and the ray also passes through one of its weak points, the weak point's
## shape is returned instead, so weak points can be hit even where the hull's
## hit shape surrounds them. Only weak points on the near side count: one
## that lies behind the hull (beyond `hull_distance_m` along the ray) is
## protected by it.
func redirect(from: Vector3, direction: Vector3, hull_distance_m: float = INF) -> Hurtbox:
	var enemy: Enemy = target as Enemy
	if enemy == null:
		return self
	var best: Hurtbox = self
	var best_along: float = INF
	for weak_point: WeakPoint in enemy.get_weak_points():
		if not weak_point.is_alive():
			continue
		var to_point: Vector3 = weak_point.global_position - from
		var along: float = to_point.dot(direction)
		if along <= 0.0 or along >= best_along:
			continue
		var radius: float = weak_point.get_hit_radius()
		if along - radius > hull_distance_m + radius * 0.5:
			continue
		if (to_point - direction * along).length() <= radius:
			best = weak_point.get_hurtbox()
			best_along = along
	return best


## Applies a hit. Returns null if the target is already dead.
func apply_hit(info: DamageInfo) -> DamageResult:
	if target == null:
		return null
	if damage_multiplier == 1.0:
		return target.apply_damage(info)
	var base_amount: float = info.amount
	info.amount = base_amount * damage_multiplier
	var result: DamageResult = target.apply_damage(info)
	info.amount = base_amount
	return result


## Turns the shape on or off (off while its target is dead or hidden).
func set_enabled(enabled: bool) -> void:
	collision_layer = layer_bits if enabled else 0


## Grows the hit sphere for a target that is far from the shooter, so distant
## targets stay hittable (see `hitbox_assist` in combat.json). The shape is
## only touched when the radius changes noticeably.
func apply_distance_assist(distance_m: float) -> void:
	if _sphere == null:
		return
	var assist: Dictionary = GameData.loader.get_config("combat").get("hitbox_assist", {})
	var wanted: float = DamageCalc.assisted_radius(_base_radius_m, distance_m, assist)
	if absf(wanted - radius_m) > radius_m * 0.04:
		radius_m = wanted
		_sphere.radius = wanted