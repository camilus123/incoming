class_name UiTheme
extends RefCounted
## The look shared by the menus (main menu, pause menu, settings, debug menu):
## dark panels with a thin cyan edge, matching the HUD and the armoury.

const COLOR_PANEL: Color = Color(0.03, 0.06, 0.09, 0.92)
const COLOR_ACCENT: Color = Color(0.6, 0.95, 1.0)
const COLOR_TEXT: Color = Color(0.86, 0.94, 0.97)
const COLOR_MUTED: Color = Color(0.5, 0.58, 0.63)
const COLOR_WARN: Color = Color(1.0, 0.7, 0.2)

static var _theme: Theme


## The shared theme (built once).
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", box(COLOR_PANEL, Color(COLOR_ACCENT, 0.35), 20.0))
	theme.set_stylebox("normal", "Button", box(Color(0.08, 0.13, 0.17), Color(COLOR_ACCENT, 0.6), 10.0))
	theme.set_stylebox("hover", "Button", box(Color(0.12, 0.2, 0.26), COLOR_ACCENT, 10.0))
	theme.set_stylebox("pressed", "Button", box(Color(0.16, 0.3, 0.36), COLOR_ACCENT, 10.0))
	theme.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.07), Color(0.25, 0.28, 0.3), 10.0))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), COLOR_ACCENT, 10.0))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(style_name, "OptionButton", theme.get_stylebox(style_name, "Button"))
	theme.set_color("font_color", "OptionButton", COLOR_TEXT)
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	theme.set_color("font_color", "CheckButton", COLOR_TEXT)
	theme.set_stylebox("panel", "TabContainer", box(Color(0.04, 0.07, 0.1, 0.6), Color(COLOR_ACCENT, 0.25), 18.0))
	theme.set_stylebox("tab_selected", "TabContainer", box(Color(0.12, 0.22, 0.28), COLOR_ACCENT, 10.0))
	theme.set_stylebox("tab_unselected", "TabContainer", box(Color(0.05, 0.08, 0.1), Color(COLOR_ACCENT, 0.25), 10.0))
	theme.set_stylebox("tab_hovered", "TabContainer", box(Color(0.09, 0.15, 0.2), Color(COLOR_ACCENT, 0.6), 10.0))
	theme.set_color("font_selected_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", COLOR_MUTED)
	theme.set_stylebox("slider", "HSlider", box(Color(0.1, 0.14, 0.18), Color(COLOR_ACCENT, 0.3), 3.0))
	theme.set_stylebox("grabber_area", "HSlider", box(Color(COLOR_ACCENT, 0.7), COLOR_ACCENT, 3.0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(COLOR_ACCENT, COLOR_ACCENT, 3.0))
	_theme = theme
	return theme


static func box(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style


static func label(text: String, font_size: int = 18, color: Color = COLOR_TEXT) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


## A button that plays the interface click.
static func button(text: String, on_pressed: Callable) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0.0, 44.0)
	node.pressed.connect(func() -> void:
		Audio.play_event("ui_click")
		on_pressed.call())
	return node
