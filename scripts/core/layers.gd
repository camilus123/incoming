class_name Layers
extends RefCounted
## Render and physics layer bit masks (names are also set in project.godot).

## Visual layers.
const RENDER_WORLD: int = 1
const RENDER_VIEWMODEL: int = 2

## Physics layers.
const PHYSICS_WORLD: int = 1
const PHYSICS_ENEMY: int = 2
const PHYSICS_ENEMY_PROJECTILE: int = 4
const PHYSICS_PLAYER: int = 8


## Puts every visual under `node` (including `node`) on the given render layers.
static func set_render_layers(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child: Node in node.get_children():
		set_render_layers(child, layer_mask)
