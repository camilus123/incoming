extends Control
## Full-screen stage messages: the intro banner, wave announcements, the
## stage-complete summary and the game-over screen. Purely a view of the
## [StageManager]; it does not exist in scenes without one (test range).

const COLOR_TITLE: Color = Color(0.6, 0.95, 1.0, 1.0)
const COLOR_TEXT: Color = Color(0.85, 0.95, 1.0, 0.95)
const COLOR_ALERT: Color = Color(1.0, 0.3, 0.25, 1.0)
const COLOR_PANEL: Color = Color(0.02, 0.05, 0.08, 0.72)
const WAVE_MESSAGE_S: float = 2.2

var _stages: StageManager
var _font: Font
var _wave_message_left_s: float = 0.0
var _wave_message: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	EventBus.wave_started.connect(_on_wave_started)


func _process(delta_s: float) -> void:
	if _stages == null:
		_stages = get_tree().get_first_node_in_group(StageManager.GROUP) as StageManager
	_wave_message_left_s = maxf(0.0, _wave_message_left_s - delta_s)
	queue_redraw()


func _draw() -> void:
	if _stages == null:
		return
	var centre: Vector2 = size * 0.5
	match _stages.state:
		StageManager.State.INTRO:
			_draw_intro(centre)
		StageManager.State.RUNNING:
			if _wave_message_left_s > 0.0:
				var color: Color = COLOR_TITLE
				color.a = clampf(_wave_message_left_s, 0.0, 1.0)
				_text(Vector2(centre.x, size.y * 0.2), _wave_message, 26, color)
		StageManager.State.COMPLETE:
			_draw_summary(centre, "STAGE %d COMPLETE" % _stages.stage_number, COLOR_TITLE, "Enter: continue to the armoury")
		StageManager.State.GAME_OVER:
			_draw_summary(centre, "TURRET DESTROYED", COLOR_ALERT, "R: back to the armoury before stage %d      Enter: start a new run" % _stages.stage_number)


func _draw_intro(centre: Vector2) -> void:
	var data: Dictionary = _stages.stage_data
	var fade: float = clampf(_stages.get_state_time() * 2.0, 0.0, 1.0)
	var title: Color = COLOR_TITLE
	title.a = fade
	var text: Color = COLOR_TEXT
	text.a = fade
	_text(Vector2(centre.x, size.y * 0.24), "STAGE %d" % _stages.stage_number, 44, title)
	_text(Vector2(centre.x, size.y * 0.24 + 36.0), str(data.get("display_name", "")).to_upper(), 22, text)
	_text(Vector2(centre.x, size.y * 0.24 + 66.0), data.get("briefing", ""), 16, text)


## Stage complete: the itemised reward. Game over: what was achieved.
func _draw_summary(centre: Vector2, title: String, title_color: Color, prompt: String) -> void:
	var rows: Array[Array] = []
	var total_row: Array = []
	if _stages.state == StageManager.State.COMPLETE:
		for line: Dictionary in _stages.reward_lines:
			rows.append([line["label"], line["detail"], "%d" % int(line["amount"])])
		total_row = ["TOTAL", "", "%d cr" % RewardCalculator.total(_stages.reward_lines)]
	else:
		var stats: StageStats = _stages.stats
		rows = [
			["Time survived", "", "%d:%02d" % [int(stats.time_s) / 60, int(stats.time_s) % 60]],
			["Enemies destroyed", "", str(stats.kills)],
			["Bombs shot down", "", str(stats.intercepts)],
			["Accuracy", "", "%d %%" % roundi(stats.accuracy_percent())],
			["Stages cleared this run", "", str(int(GameState.statistics.get("stages_cleared", 0)))],
		]

	var height: float = 150.0 + rows.size() * 28.0 + (44.0 if not total_row.is_empty() else 0.0)
	var panel: Rect2 = Rect2(centre - Vector2(340.0, height * 0.5 + 20.0), Vector2(680.0, height))
	draw_rect(panel, COLOR_PANEL)
	draw_rect(panel, title_color, false, 2.0)
	_text(Vector2(centre.x, panel.position.y + 52.0), title, 34, title_color)

	var y: float = panel.position.y + 100.0
	for row: Array in rows:
		_text(Vector2(panel.position.x + 50.0, y), row[0], 17, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(panel.position.x + 400.0, y), row[1], 15, Color(COLOR_TEXT, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(panel.end.x - 50.0, y), row[2], 17, COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 28.0
	if not total_row.is_empty():
		y += 6.0
		draw_line(Vector2(panel.position.x + 50.0, y - 18.0), Vector2(panel.end.x - 50.0, y - 18.0), title_color, 1.0)
		_text(Vector2(panel.position.x + 50.0, y + 6.0), total_row[0], 20, title_color, HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(panel.end.x - 50.0, y + 6.0), total_row[2], 20, title_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(centre.x, panel.end.y - 20.0), prompt, 15, title_color)

func _par() -> float:
	return _stages.stage_data.get("par_time_s", 0.0)


func _text(at: Vector2, text: String, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var text_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = at
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= text_width * 0.5
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= text_width
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _on_wave_started(_stage: int, wave: int) -> void:
	if _stages == null:
		return
	_wave_message = "WAVE %d / %d" % [wave, _stages.get_wave_count()]
	_wave_message_left_s = WAVE_MESSAGE_S
