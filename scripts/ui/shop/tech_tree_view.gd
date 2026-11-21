class_name TechTreeView
extends Control
## The tech tree as a zoomable, pannable node graph.
##
## Everything shown comes from data: node positions (`ui.x`, `ui.y`), names,
## costs, links (prerequisites) and branch colours. Node states come from
## [GameState]. This control only draws and reports clicks; buying and
## refunding are done by the shop screen.
##
## Mouse: drag to pan, wheel to zoom, left click a node to buy it, right
## click to refund it.

signal node_hovered(id: String)
signal node_activated(id: String)
signal node_refund_requested(id: String)

const NODE_SIZE: Vector2 = Vector2(250.0, 84.0)
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 1.8
const ZOOM_STEP: float = 1.12
const CLICK_SLOP_PX: float = 6.0
const COLOR_BACKGROUND: Color = Color(0.02, 0.035, 0.05, 0.92)
const COLOR_TEXT: Color = Color(0.9, 0.96, 1.0)
const COLOR_MUTED: Color = Color(0.5, 0.56, 0.62)
const COLOR_LINK: Color = Color(0.35, 0.4, 0.46)
const COLOR_DENIED: Color = Color(1.0, 0.35, 0.3)

var _pan: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _hovered: String = ""
var _dragging: bool = false
var _drag_distance: float = 0.0
var _time_s: float = 0.0
var _font: Font


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	GameState.changed.connect(queue_redraw)
	resized.connect(_on_resized)


func _process(delta_s: float) -> void:
	if is_visible_in_tree():
		_time_s += delta_s
		queue_redraw()  # Available nodes pulse.


## Zooms and pans so the whole tree is visible.
func fit_to_view() -> void:
	var bounds: Rect2 = _tree_bounds()
	if bounds.size.x <= 0.0 or size.x <= 0.0:
		return
	_zoom = clampf(minf(size.x / bounds.size.x, size.y / bounds.size.y) * 0.94, ZOOM_MIN, ZOOM_MAX)
	_pan = size * 0.5 - bounds.get_center() * _zoom
	queue_redraw()


func _on_resized() -> void:
	fit_to_view()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(button.position, ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(button.position, 1.0 / ZOOM_STEP)
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if button.pressed:
				_dragging = true
				_drag_distance = 0.0
			else:
				_dragging = false
				# A press and release without movement is a click.
				if _drag_distance < CLICK_SLOP_PX:
					var id: String = _node_at(button.position)
					if not id.is_empty() and button.button_index == MOUSE_BUTTON_LEFT:
						node_activated.emit(id)
					elif not id.is_empty() and button.button_index == MOUSE_BUTTON_RIGHT:
						node_refund_requested.emit(id)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _dragging:
			_pan += motion.relative
			_drag_distance += motion.relative.length()
			queue_redraw()
		_set_hovered(_node_at(motion.position))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_dragging = false
		_set_hovered("")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	var tree: TechTree = GameState.tree
	draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))
	for id: String in tree.get_node_ids():
		_draw_links(tree, id)
	_draw_branch_labels(tree)
	for id: String in tree.get_node_ids():
		_draw_node(tree, id)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_links(tree: TechTree, id: String) -> void:
	var tree_node: Dictionary = tree.get_node(id)
	var requires: Dictionary = tree_node.get("requires", {})
	var to: Vector2 = _node_rect(tree_node).get_center()
	var owned: bool = GameState.purchased.has(id)
	for required: String in requires.get("all_of", []):
		if tree.has_node(required):
			draw_line(_node_rect(tree.get_node(required)).get_center(), to, _link_color(tree, id, required, owned), 3.0, true)
	# "Any one of" links are dashed.
	for required: String in requires.get("any_of", []):
		if tree.has_node(required):
			draw_dashed_line(_node_rect(tree.get_node(required)).get_center(), to, _link_color(tree, id, required, owned), 3.0, 10.0)


func _link_color(tree: TechTree, id: String, required: String, owned: bool) -> Color:
	if GameState.purchased.has(required) and (owned or GameState.get_node_state(id) == TechTree.NodeState.AVAILABLE):
		return _branch_color(tree, id)
	return COLOR_LINK


## Names each branch above its first (top-left) node.
func _draw_branch_labels(tree: TechTree) -> void:
	var firsts: Dictionary = {}
	for id: String in tree.get_node_ids():
		var tree_node: Dictionary = tree.get_node(id)
		var branch: String = tree_node.get("branch", "")
		var position: Vector2 = _node_rect(tree_node).position
		if not firsts.has(branch) or position.y < firsts[branch].y or (position.y == firsts[branch].y and position.x < firsts[branch].x):
			firsts[branch] = position
	for branch: String in firsts:
		var color_values: Array = tree.get_branch(branch).get("color", [0.6, 0.9, 1.0])
		draw_string(_font, firsts[branch] + Vector2(2.0, -9.0), str(tree.get_branch(branch).get("display_name", branch)).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(color_values[0], color_values[1], color_values[2], 0.85))


func _draw_node(tree: TechTree, id: String) -> void:
	var tree_node: Dictionary = tree.get_node(id)
	var rect: Rect2 = _node_rect(tree_node)
	var branch_color: Color = _branch_color(tree, id)
	var state: int = GameState.get_node_state(id)

	var fill: Color = Color(0.05, 0.06, 0.075)
	var border: Color = Color(0.28, 0.31, 0.35)
	var text: Color = COLOR_MUTED
	var status: String = "%d cr" % tree.get_cost(id)
	var status_color: Color = COLOR_MUTED
	var border_width: float = 2.0
	match state:
		TechTree.NodeState.PURCHASED:
			fill = Color(branch_color.r * 0.4, branch_color.g * 0.4, branch_color.b * 0.4)
			border = branch_color
			text = COLOR_TEXT
			status = "OWNED"
			status_color = branch_color.lightened(0.3)
		TechTree.NodeState.AVAILABLE:
			fill = Color(0.07, 0.1, 0.13)
			border = branch_color.lerp(Color.WHITE, 0.25 + 0.25 * sin(_time_s * 4.0))
			border_width = 3.0
			text = COLOR_TEXT
			status_color = COLOR_TEXT if GameState.credits >= tree.get_cost(id) else COLOR_DENIED
		TechTree.NodeState.EXCLUDED:
			fill = Color(0.13, 0.05, 0.05)
			border = Color(0.45, 0.18, 0.16)
			status = "LOCKED OUT"
			status_color = Color(0.7, 0.3, 0.27)
		GameState.STATE_UNAVAILABLE:
			fill = Color(0.045, 0.045, 0.05)
			border = Color(0.2, 0.2, 0.22)
			text = Color(0.36, 0.38, 0.42)
			status = "LATER BUILD"

	draw_rect(rect, fill)
	draw_rect(rect, border, false, border_width)
	if id == _hovered:
		draw_rect(rect.grow(3.0), Color.WHITE, false, 2.0)

	# "Bastion I: Dense Emitters" is shown on two lines.
	var name: String = tree_node.get("name", id)
	var lines: PackedStringArray = name.split(": ", true, 1)
	var width: float = rect.size.x - 20.0
	draw_string(_font, rect.position + Vector2(10.0, 28.0), lines[0], HORIZONTAL_ALIGNMENT_LEFT, width, 19, text)
	if lines.size() > 1:
		draw_string(_font, rect.position + Vector2(10.0, 50.0), lines[1], HORIZONTAL_ALIGNMENT_LEFT, width, 16, Color(text, 0.75))
	draw_string(_font, rect.position + Vector2(10.0, rect.size.y - 9.0), status, HORIZONTAL_ALIGNMENT_RIGHT, width, 16, status_color)
	if state == TechTree.NodeState.EXCLUDED:
		draw_line(rect.position, rect.end, Color(0.45, 0.18, 0.16, 0.6), 2.0)


func _branch_color(tree: TechTree, id: String) -> Color:
	var color_values: Array = tree.get_branch(tree.get_node(id).get("branch", "")).get("color", [0.6, 0.9, 1.0])
	return Color(color_values[0], color_values[1], color_values[2])


func _node_rect(tree_node: Dictionary) -> Rect2:
	var ui: Dictionary = tree_node.get("ui", {})
	return Rect2(Vector2(ui.get("x", 0.0), ui.get("y", 0.0)), NODE_SIZE)


func _tree_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for id: String in GameState.tree.get_node_ids():
		var rect: Rect2 = _node_rect(GameState.tree.get_node(id)).grow(24.0)
		bounds = rect if first else bounds.merge(rect)
		first = false
	return bounds


## Id of the node under a point of this control, or "".
func _node_at(point: Vector2) -> String:
	var tree_point: Vector2 = (point - _pan) / _zoom
	for id: String in GameState.tree.get_node_ids():
		if _node_rect(GameState.tree.get_node(id)).has_point(tree_point):
			return id
	return ""


func _zoom_at(point: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	# Keep the tree point under the cursor where it is.
	_pan = point - (point - _pan) * (new_zoom / _zoom)
	_zoom = new_zoom
	queue_redraw()


func _set_hovered(id: String) -> void:
	if id == _hovered:
		return
	_hovered = id
	node_hovered.emit(id)
	queue_redraw()
