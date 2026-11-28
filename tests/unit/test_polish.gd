extends GutTest
## Polish milestone (M8): audio data, rebinding, difficulty, renderer choice
## and the menus. Settings are put back after every test and never saved.

var _saved_bindings: Dictionary
var _saved_difficulty: String
var _saved_driver: String
var _was_persistent: bool


func before_each() -> void:
	_saved_bindings = (UserSettings.get_value(UserSettings.BINDINGS) as Dictionary).duplicate(true)
	_saved_difficulty = str(UserSettings.get_value(UserSettings.DIFFICULTY))
	_saved_driver = str(UserSettings.get_value(UserSettings.RENDERING_DRIVER))
	_was_persistent = GameState.persistent
	GameState.persistent = false
	# Nothing in these tests may reach the player's settings file.
	UserSettings.read_only = true


func after_each() -> void:
	UserSettings.set_value(UserSettings.BINDINGS, _saved_bindings)
	UserSettings.set_value(UserSettings.DIFFICULTY, _saved_difficulty)
	UserSettings.set_value(UserSettings.RENDERING_DRIVER, _saved_driver)
	InputSetup.apply(GameData.loader.get_config("input"))
	UserSettings.read_only = false
	GameState.persistent = _was_persistent
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false


# --- Audio --------------------------------------------------------------------

func test_every_weapon_has_a_fire_sound_that_exists() -> void:
	var weapons: Dictionary = GameData.loader.get_category("weapons")
	for weapon_id: String in weapons:
		var sound: String = (weapons[weapon_id].get("audio", {}) as Dictionary).get("fire", "")
		assert_false(sound.is_empty(), "%s names a fire sound" % weapon_id)
		assert_true(GameData.assets.has_asset(sound), "%s: '%s' is in the manifest" % [weapon_id, sound])
		assert_true(GameData.assets.load_asset(sound) is AudioStream, "%s: '%s' loads as audio" % [weapon_id, sound])


func test_every_audio_event_uses_a_bus_and_a_sound_that_exist() -> void:
	var audio: Dictionary = GameData.loader.get_config("audio")
	for bus_name: String in audio["buses"]:
		assert_gte(AudioServer.get_bus_index(bus_name), 0, "bus %s was created" % bus_name)
	for event_name: String in audio["events"]:
		var event: Dictionary = audio["events"][event_name]
		assert_true((audio["buses"] as Dictionary).has(event["bus"]), "%s: bus" % event_name)
		if not str(event["sound"]).is_empty():
			assert_true(GameData.assets.load_asset(event["sound"]) is AudioStream, "%s: sound loads" % event_name)


func test_the_six_buses_of_the_spec_exist() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "Weapons", "UI", "Alerts"]:
		assert_gte(AudioServer.get_bus_index(bus_name), 0, bus_name)


func test_a_volume_setting_moves_its_bus() -> void:
	var index: int = AudioServer.get_bus_index("Music")
	var before: float = float(UserSettings.get_value(UserSettings.VOLUME_MUSIC))
	UserSettings.set_value(UserSettings.VOLUME_MUSIC, 1.0)
	var full_db: float = AudioServer.get_bus_volume_db(index)
	UserSettings.set_value(UserSettings.VOLUME_MUSIC, 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), full_db + linear_to_db(0.5), 0.01)
	UserSettings.set_value(UserSettings.VOLUME_MUSIC, 0.0)
	assert_true(AudioServer.is_bus_mute(index), "zero mutes the bus")
	UserSettings.set_value(UserSettings.VOLUME_MUSIC, before)


func test_sounds_can_be_asked_for_without_a_listener() -> void:
	# The tests run headless and muted; this only has to be safe to call.
	Audio.play_event("ui_click")
	Audio.play_event("explosion", "audio.explosion.small", Vector3(0, 100, -500))
	Audio.play_event("no_such_event")
	assert_null(Audio.make_engine_loop(""), "no engine sound, no player")
	pass_test("no errors")


# --- Rebinding ----------------------------------------------------------------

func test_rebinding_an_action_changes_the_input_map() -> void:
	InputSetup.rebind("fire_primary", [{"key": "F"}])
	var events: Array[InputEvent] = InputMap.action_get_events(&"fire_primary")
	assert_eq(events.size(), 1)
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_F)
	assert_eq(InputSetup.describe("fire_primary"), "F")


func test_a_key_given_to_one_action_is_taken_from_the_other() -> void:
	InputSetup.rebind("retry", [{"key": "Tab"}])
	assert_eq(InputSetup.describe("retry"), "Tab")
	assert_eq(InputSetup.describe("show_intel"), "not bound", "Tab cannot do two things")


func test_swapping_the_wheel_direction() -> void:
	InputSetup.reset_all()
	InputSetup.swap("power_to_weapons", "power_to_shields")
	assert_eq(InputSetup.describe("power_to_weapons"), "Wheel down")
	assert_eq(InputSetup.describe("power_to_shields"), "Wheel up")


func test_reset_restores_the_data_defaults() -> void:
	InputSetup.rebind("fire_primary", [{"key": "F"}])
	InputSetup.reset_all()
	assert_eq(InputSetup.describe("fire_primary"), "Left mouse")
	assert_true((UserSettings.get_value(UserSettings.BINDINGS) as Dictionary).is_empty())


# --- Difficulty ---------------------------------------------------------------

func test_a_new_run_takes_the_chosen_difficulty_and_keeps_it() -> void:
	UserSettings.set_value(UserSettings.DIFFICULTY, "hard")
	GameState.new_run()
	assert_eq(GameState.difficulty_id, "hard")
	assert_eq(GameState.get_difficulty()["display_name"], "Hard")
	UserSettings.set_value(UserSettings.DIFFICULTY, "easy")
	assert_eq(GameState.difficulty_id, "hard", "a running run keeps its difficulty")
	var saved: Dictionary = GameState.to_save_data()
	assert_eq(saved["difficulty"], "hard")
	GameState.new_run()
	assert_eq(GameState.difficulty_id, "easy")
	GameState.apply_save_data(saved)
	assert_eq(GameState.difficulty_id, "hard", "and it survives save and load")


func test_an_old_save_without_difficulty_loads_as_the_default() -> void:
	GameState.new_run()
	var saved: Dictionary = GameState.to_save_data()
	saved.erase("difficulty")
	GameState.apply_save_data(saved)
	assert_eq(GameState.difficulty_id, GameData.loader.get_config("difficulty")["default"])


func test_an_unknown_difficulty_setting_falls_back() -> void:
	UserSettings.set_value(UserSettings.DIFFICULTY, "impossible")
	assert_eq(GameState.chosen_difficulty_id(), GameData.loader.get_config("difficulty")["default"])


# --- Renderer -----------------------------------------------------------------

func test_renderer_choice_only_accepts_known_drivers() -> void:
	assert_false(RendererChoice.choose("opengl"), "not offered")
	UserSettings.set_value(UserSettings.RENDERING_DRIVER, "nonsense")
	assert_eq(RendererChoice.get_chosen(), "vulkan")
	UserSettings.set_value(UserSettings.RENDERING_DRIVER, "d3d12")
	assert_eq(RendererChoice.get_chosen(), "d3d12")
	assert_true(RendererChoice.override_path().ends_with("override.cfg"))


# --- Menus --------------------------------------------------------------------

func test_the_settings_menu_builds_with_all_four_pages() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	var tabs: TabContainer = menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var titles: Array[String] = []
	for index: int in tabs.get_tab_count():
		titles.append(tabs.get_tab_title(index))
	assert_eq(titles, ["Controls", "Video", "Audio", "Accessibility"] as Array[String])
	var actions: Dictionary = GameData.loader.get_config("input")["actions"]
	assert_eq(menu._binding_buttons.size(), actions.size(), "one binding button per action")


func test_the_main_menu_scene_loads() -> void:
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_seconds(0.1)
	assert_not_null(menu.find_child("Environment", true, false), "the frontier is behind the menu")
	var labels: Array[String] = []
	for button: Node in menu.find_children("*", "Button", true, false):
		labels.append((button as Button).text)
	for expected: String in ["New run", "Settings", "Quit"]:
		assert_true(labels.has(expected), "button '%s'" % expected)


func test_pausing_opens_the_pause_menu_and_resume_closes_it() -> void:
	GameState.new_run()
	var game: PlayScene = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_seconds(0.1)
	var pause_menu: PauseMenu = game.get_node("PauseMenu")
	assert_false(pause_menu.visible)
	game._set_paused(true)
	assert_true(pause_menu.visible)
	assert_true(get_tree().paused)
	pause_menu.resume_requested.emit()
	assert_false(pause_menu.visible)
	assert_false(get_tree().paused)


func test_the_debug_menu_can_skip_a_stage() -> void:
	GameState.new_run()
	var game: PlayScene = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_seconds(0.1)
	var stages: StageManager = game.get_node("StageManager")
	stages.start_stage(1)
	await wait_seconds(0.2)
	stages.debug_skip_stage()
	assert_eq(stages.state, StageManager.State.COMPLETE)
