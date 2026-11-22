extends Control
## The armoury between stages: tech tree, loadout, hull repair and the
## preview of the next stage. Shown while the [StageManager] is in the SHOP
## state. All content comes from data and [GameState].
##
## Debug builds: F2 adds 1,000 credits.

const SIDEBAR_WIDTH: float = 440.0
const COLOR_PANEL: Color = Color(0.03, 0.05, 0.07, 0.95)
const COLOR_ACCENT: Color = Color(0.6, 0.95, 1.0)
const COLOR_TEXT: Color = Color(0.86, 0.93, 0.98)
const COLOR_MUTED: Color = Color(0.55, 0.62, 0.68)
const DEBUG_CREDITS: int = 1000

var _stages: StageManager
var _tree_view: TechTreeView
var _title: Label
var _credits: Label
var _hull_label: Label
var _hull_bar: ProgressBar
var _repair_button: Button
var _slot_pickers: Dictionary = {}   # slot -> OptionButton
var _slot_details: Dictionary = {}   # slot -> Label
var _shield_label: Label
var _stage_title: Label
var _stage_briefing: Label
var _stage_enemies: Label
var _continue_button: Button
var _new_run_button: Button
var _new_run_armed: bool = false
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel
var _hovered_node: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()
	_build_layout()
	visible = false
	GameState.changed.connect(_on_run_changed)
	_connect_stage_manager.call_deferred()


func _connect_stage_manager() -> void:
	_stages = get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
	if _stages != null:
		_stages.state_changed.connect(_on_stage_state_changed)
		_on_stage_state_changed(_stages.state)


func _process(_delta_s: float) -> void:
	if not visible or _hovered_node.is_empty():
		_tooltip.visible = false
		return
	# Keep the tooltip next to the pointer and inside the screen.
	_tooltip.visible = true
	_tooltip.reset_size()
	var mouse: Vector2 = get_local_mouse_position()
	var position: Vector2 = mouse + Vector2(22.0, 18.0)
	if position.x + _tooltip.size.x > size.x - 8.0:
		position.x = mouse.x - _tooltip.size.x - 16.0
	if position.y + _tooltip.size.y > size.y - 8.0:
		position.y = maxf(8.0, size.y - _tooltip.size.y - 8.0)
	_tooltip.position = position


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if visible and OS.is_debug_build() and key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		GameState.add_credits(DEBUG_CREDITS)
		get_viewport().set_input_as_handled()


# --- Events ------------------------------------------------------------------

func _on_stage_state_changed(state: StageManager.State) -> void:
	visible = state == StageManager.State.SHOP
	if visible:
		_new_run_armed = false
		_refresh()
		_tree_view.fit_to_view.call_deferred()


func _on_run_changed() -> void:
	if not visible:
		return
	_refresh()
	# Show the new guns and shield on the turret behind the shop straight away.
	var turret: Turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	if turret != null:
		turret.apply_player_state()
		turret.restore_for_stage()


func _on_node_activated(id: String) -> void:
	if GameState.buy(id):
		_update_tooltip()


func _on_node_refund_requested(id: String) -> void:
	if GameState.refund(id):
		_update_tooltip()


func _on_node_hovered(id: String) -> void:
	_hovered_node = id
	_update_tooltip()


func _on_slot_selected(index: int, slot: String) -> void:
	var picker: OptionButton = _slot_pickers[slot]
	GameState.equip(slot, str(picker.get_item_metadata(index)))


func _on_new_run_pressed() -> void:
	# Two clicks, so a run is not thrown away by accident.
	if not _new_run_armed:
		_new_run_armed = true
		_new_run_button.text = "Click again to discard this run"
		return
	_new_run_armed = false
	GameState.new_run()
	if _stages != null:
		_stages.open_shop()


# --- Content -----------------------------------------------------------------

func _refresh() -> void:
	_title.text = "ARMOURY  ·  BEFORE STAGE %d" % GameState.stage
	_credits.text = "%s cr" % _thousands(GameState.credits)

	var max_hull: float = GameState.get_max_hull()
	var hull: float = GameState.get_current_hull()
	_hull_label.text = "HULL  %d / %d" % [ceili(hull), ceili(max_hull)]
	_hull_bar.max_value = max_hull
	_hull_bar.value = hull
	var repair_cost: int = GameState.get_repair_cost()
	_repair_button.disabled = repair_cost <= 0 or GameState.credits <= 0
	if repair_cost <= 0:
		_repair_button.text = "Hull at full strength"
	elif GameState.credits >= repair_cost:
		_repair_button.text = "Repair hull  (%d cr)" % repair_cost
	else:
		_repair_button.text = "Repair what you can afford  (%d cr)" % GameState.credits

	var shield: Dictionary = GameState.get_shield_data()
	_shield_label.text = "%s:  %d capacity,  %s/s recharge,  %s s delay" % [
		shield.get("display_name", "Shield"), int(shield.get("capacity", 0.0)),
		_number(shield.get("recharge_per_s", 0.0)), _number(shield.get("recharge_delay_s", 0.0))]

	for slot: String in GameState.SLOTS:
		var picker: OptionButton = _slot_pickers[slot]
		picker.clear()
		for weapon_id: String in GameState.get_owned_weapons():
			if GameState.can_equip(slot, weapon_id):
				picker.add_item(GameState.get_weapon_data(weapon_id).get("display_name", weapon_id))
				picker.set_item_metadata(picker.item_count - 1, weapon_id)
				if GameState.loadout.get(slot, "") == weapon_id:
					picker.select(picker.item_count - 1)
		(_slot_details[slot] as Label).text = _weapon_summary(GameState.get_weapon_data(GameState.loadout.get(slot, "")))

	var stage_data: Dictionary = _stages.get_stage_data(GameState.stage) if _stages != null else {}
	var stage_name: String = str(stage_data.get("display_name", "")).to_upper()
	_stage_title.text = "NEXT:  STAGE %d" % GameState.stage + ("  ·  " + stage_name if not stage_name.is_empty() else "")
	_stage_briefing.text = stage_data.get("briefing", "")
	_stage_enemies.text = "Expected:  " + ", ".join(_expected_enemies(stage_data))
	_continue_button.text = "CONTINUE TO STAGE %d" % GameState.stage
	if not _new_run_armed:
		_new_run_button.text = "Start a new run"


## Display names of the enemy types a stage can contain.
func _expected_enemies(stage_data: Dictionary) -> PackedStringArray:
	var enemies: Dictionary = GameData.loader.get_category("enemies")
	var ids: Array[String] = []
	for wave: Dictionary in stage_data.get("waves", []):
		for group: Dictionary in wave.get("groups", []):
			if not ids.has(group["enemy"]):
				ids.append(group["enemy"])
		if float(wave.get("budget_share", 0.0)) > 0.0:
			var listed: Array = wave.get("enemies", [])
			if listed.is_empty():
				listed = WaveDirector.enemy_pool(GameState.stage, enemies)
			for enemy_id: String in listed:
				if not ids.has(enemy_id):
					ids.append(enemy_id)
	var names: PackedStringArray = []
	for enemy_id: String in ids:
		names.append(enemies.get(enemy_id, {}).get("display_name", enemy_id))
	return names


func _weapon_summary(weapon: Dictionary) -> String:
	if weapon.is_empty():
		return "Nothing equipped"
	var parts: PackedStringArray = [str(weapon.get("damage_type", "")).capitalize(), "%s damage" % _number(weapon.get("damage", 0.0))]
	if weapon.has("homing"):
		var homing: Dictionary = weapon["homing"]
		parts.append("%d per salvo" % int(homing.get("salvo_size", 1)))
		parts.append("%s s reload" % _number(homing.get("reload_s", 0.0)))
	else:
		parts.append("%s shots/s" % _number(weapon.get("fire_rate", 0.0)))
	if int(weapon.get("ammo_per_stage", 0)) > 0:
		parts.append("%d ammo per stage" % int(weapon["ammo_per_stage"]))
	return ",  ".join(parts)


func _update_tooltip() -> void:
	if _hovered_node.is_empty():
		return
	var tree: TechTree = GameState.tree
	var tree_node: Dictionary = tree.get_node(_hovered_node)
	var state: int = GameState.get_node_state(_hovered_node)
	var lines: PackedStringArray = []
	lines.append("[b][font_size=19]%s[/font_size][/b]" % tree_node.get("name", _hovered_node))
	lines.append("[color=#8fa3b3]%s[/color]" % tree.get_branch(tree_node.get("branch", "")).get("display_name", ""))
	if not str(tree_node.get("description", "")).is_empty():
		lines.append("")
		lines.append(tree_node["description"])

	var stat_lines: PackedStringArray = []
	for effect: Dictionary in tree_node.get("effects", []):
		if effect.has("unlock"):
			var weapon: Dictionary = GameState.get_weapon_data(effect["unlock"])
			if weapon.is_empty():
				stat_lines.append("Unlocks a weapon that is not in this build yet.")
			else:
				stat_lines.append("Unlocks [b]%s[/b]" % weapon.get("display_name", effect["unlock"]))
				stat_lines.append("    " + _weapon_summary(weapon))
				stat_lines.append("    Slots: " + ", ".join(PackedStringArray(weapon.get("allowed_slots", []))))
	# Before and after for every stat the node changes.
	for change: Dictionary in GameState.preview_node(_hovered_node):
		if state == TechTree.NodeState.PURCHASED:
			stat_lines.append("%s:  [b]%s[/b]" % [change["label"], _value(change["after"])])
		else:
			stat_lines.append("%s:  %s  →  [b][color=#9ff0ff]%s[/color][/b]" % [change["label"], _value(change["before"]), _value(change["after"])])
	if not stat_lines.is_empty():
		lines.append("")
		lines.append_array(stat_lines)

	lines.append("")
	match state:
		TechTree.NodeState.PURCHASED:
			if GameState.can_refund(_hovered_node):
				lines.append("[color=#8fa3b3]Owned. Right click to refund %d cr.[/color]" % GameState.get_refund_value(_hovered_node))
			elif tree_node.get("owned_at_start", false):
				lines.append("[color=#8fa3b3]Standard equipment.[/color]")
			else:
				lines.append("[color=#8fa3b3]Owned. Refund the upgrades that depend on it first.[/color]")
		TechTree.NodeState.AVAILABLE:
			if GameState.credits >= tree.get_cost(_hovered_node):
				lines.append("[color=#9ff0ff]Left click to buy for %d cr.[/color]" % tree.get_cost(_hovered_node))
			else:
				lines.append("[color=#ff6a5c]Costs %d cr. You need %d more.[/color]" % [tree.get_cost(_hovered_node), tree.get_cost(_hovered_node) - GameState.credits])
		TechTree.NodeState.LOCKED:
			lines.append("Costs %d cr." % tree.get_cost(_hovered_node))
			lines.append("[color=#ffb347]%s[/color]" % _requirements_text(tree, tree_node))
		TechTree.NodeState.EXCLUDED:
			lines.append("[color=#ff6a5c]Locked out by the branch you chose. Refund that branch to open this one.[/color]")
		GameState.STATE_UNAVAILABLE:
			lines.append("[color=#8fa3b3]Not in this build yet. Its weapon arrives with the content pass.[/color]")
	_tooltip_text.text = "\n".join(lines)


func _requirements_text(tree: TechTree, tree_node: Dictionary) -> String:
	var requires: Dictionary = tree_node.get("requires", {})
	var parts: PackedStringArray = []
	var all_names: PackedStringArray = []
	for required: String in requires.get("all_of", []):
		if not GameState.purchased.has(required):
			all_names.append(tree.get_node(required).get("name", required))
	if not all_names.is_empty():
		parts.append("Requires " + ", ".join(all_names) + ".")
	var any_names: PackedStringArray = []
	for required: String in requires.get("any_of", []):
		any_names.append(tree.get_node(required).get("name", required))
	if not any_names.is_empty() and not tree.prerequisites_met(tree_node.get("id", ""), GameState.purchased):
		parts.append("Requires one of: " + ", ".join(any_names) + ".")
	return " ".join(parts)


func _value(value: Variant) -> String:
	if value == null:
		return "none"
	if value is bool:
		return "on" if value else "off"
	if value is float or value is int:
		return _number(value)
	return str(value)


func _number(value: Variant) -> String:
	var number: float = float(value)
	return str(int(roundf(number))) if is_equal_approx(number, roundf(number)) else String.num(number, 2)


func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var result: String = ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return ("-" if value < 0 else "") + text + result


# --- Layout ------------------------------------------------------------------

func _build_layout() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	margin.add_child(columns)

	# Left: the tree, with a hint line under it.
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_tree_view = TechTreeView.new()
	_tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_view.node_hovered.connect(_on_node_hovered)
	_tree_view.node_activated.connect(_on_node_activated)
	_tree_view.node_refund_requested.connect(_on_node_refund_requested)
	left.add_child(_tree_view)
	var hint_text: String = "Left click: buy      Right click: refund      Drag: pan      Wheel: zoom"
	if OS.is_debug_build():
		hint_text += "      F2: +%d credits (debug)" % DEBUG_CREDITS
	left.add_child(_label(hint_text, 14, COLOR_MUTED))

	# Right: the run.
	var sidebar: PanelContainer = PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0.0)
	columns.add_child(sidebar)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	sidebar.add_child(box)

	_title = _label("", 16, COLOR_MUTED)
	box.add_child(_title)
	_credits = _label("", 40, COLOR_ACCENT)
	box.add_child(_credits)
	box.add_child(HSeparator.new())

	_hull_label = _label("", 16, COLOR_TEXT)
	box.add_child(_hull_label)
	_hull_bar = ProgressBar.new()
	_hull_bar.show_percentage = false
	_hull_bar.custom_minimum_size = Vector2(0.0, 12.0)
	box.add_child(_hull_bar)
	_repair_button = Button.new()
	_repair_button.pressed.connect(func() -> void: GameState.repair_hull())
	box.add_child(_repair_button)
	_shield_label = _label("", 14, COLOR_MUTED)
	_shield_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_shield_label)
	box.add_child(HSeparator.new())

	box.add_child(_label("LOADOUT", 16, COLOR_TEXT))
	for slot: String in GameState.SLOTS:
		box.add_child(_label(slot.to_upper(), 13, COLOR_MUTED))
		var picker: OptionButton = OptionButton.new()
		picker.item_selected.connect(_on_slot_selected.bind(slot))
		box.add_child(picker)
		_slot_pickers[slot] = picker
		var details: Label = _label("", 13, COLOR_MUTED)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(details)
		_slot_details[slot] = details
	box.add_child(HSeparator.new())

	_stage_title = _label("", 16, COLOR_TEXT)
	_stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stage_title)
	_stage_briefing = _label("", 14, COLOR_MUTED)
	_stage_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stage_briefing)
	_stage_enemies = _label("", 14, COLOR_TEXT)
	_stage_enemies.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stage_enemies)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0.0, 64.0)
	_continue_button.add_theme_font_size_override("font_size", 22)
	_continue_button.pressed.connect(func() -> void:
		if _stages != null:
			_stages.continue_from_shop())
	box.add_child(_continue_button)
	_new_run_button = Button.new()
	_new_run_button.flat = true
	_new_run_button.add_theme_font_size_override("font_size", 13)
	_new_run_button.pressed.connect(_on_new_run_pressed)
	box.add_child(_new_run_button)

	# Tooltip, drawn above everything else.
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip.custom_minimum_size = Vector2(430.0, 0.0)
	add_child(_tooltip)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.scroll_active = false
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.custom_minimum_size = Vector2(400.0, 0.0)
	_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.add_child(_tooltip_text)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_theme() -> Theme:
	var shop_theme: Theme = Theme.new()
	shop_theme.default_font_size = 16
	shop_theme.set_stylebox("panel", "PanelContainer", _box(COLOR_PANEL, Color(COLOR_ACCENT, 0.35), 16.0))
	shop_theme.set_stylebox("normal", "Button", _box(Color(0.08, 0.13, 0.17), Color(COLOR_ACCENT, 0.6), 8.0))
	shop_theme.set_stylebox("hover", "Button", _box(Color(0.12, 0.2, 0.26), COLOR_ACCENT, 8.0))
	shop_theme.set_stylebox("pressed", "Button", _box(Color(0.16, 0.3, 0.36), COLOR_ACCENT, 8.0))
	shop_theme.set_stylebox("disabled", "Button", _box(Color(0.05, 0.06, 0.07), Color(0.25, 0.28, 0.3), 8.0))
	shop_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	shop_theme.set_color("font_color", "Button", COLOR_TEXT)
	shop_theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		shop_theme.set_stylebox(style_name, "OptionButton", shop_theme.get_stylebox(style_name, "Button"))
	shop_theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	shop_theme.set_stylebox("background", "ProgressBar", _box(Color(0.08, 0.1, 0.12), Color(0.2, 0.25, 0.3), 0.0))
	shop_theme.set_stylebox("fill", "ProgressBar", _box(COLOR_ACCENT, COLOR_ACCENT, 0.0))
	shop_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	return shop_theme


func _box(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(padding)
	return box
