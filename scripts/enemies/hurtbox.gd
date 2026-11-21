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
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	hurtbox.add_child(collision)
	return hurtbox


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
