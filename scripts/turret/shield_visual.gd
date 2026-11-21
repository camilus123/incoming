class_name ShieldVisual
extends Node3D
## Base class of the visible shield. The style is chosen per shield in data
## (`visuals.style`): "dome" is a large bubble around the emplacement,
## "conformal" is an energy skin that hugs the turret and guns.
## Presentation only; the shield's numbers live in [ShieldState].


## Creates the visual for a style name. Unknown styles fall back to the dome.
static func create(style: String) -> ShieldVisual:
	if style == "conformal":
		return ShieldSkin.new()
	return ShieldDome.new()


## The style name this visual implements.
func get_style() -> String:
	return ""


## Applies the "visuals" block of a shield data file.
func configure(_visuals: Dictionary) -> void:
	pass


## Gives the visual the turret model it protects. Called again whenever the
## model's parts change (a weapon was swapped).
func attach(_model_root: Node3D) -> void:
	pass


## Removes anything the visual added to the turret model.
func detach() -> void:
	pass


## Shows how full the shield is (0 = invisible).
func set_charge(_fraction: float) -> void:
	pass


## Reacts to a hit that came from `from_position`.
func add_impact(_from_position: Vector3) -> void:
	pass


## Lights up the whole shield briefly (it broke or came back).
func flash(_strength: float = 1.0) -> void:
	pass
