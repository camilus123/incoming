extends Node
## Autoload "Audio": every sound in the game goes through here.
##
## - Buses (Master, Music, SFX, Weapons, UI, Alerts) are created from
##   `data/config/audio.json`; their volumes are the player's settings.
## - Sounds are asset ids, resolved through the manifest like models.
## - Players are pooled: a fixed number of plain players (interface, the
##   player's own weapons, alerts) and of 3D players (explosions, enemies).
##   When all are busy the oldest is reused.
## - It listens to the event bus, so gameplay code does not call it: firing a
##   weapon, an explosion, a shield hit and so on each emit their signal and
##   the matching sound plays. Interface code calls `play_event("ui_click")`.
##
## Voice alerts ("Shields down") are tones plus the HUD message for now; the
## Alerts bus and the event names are in place for recorded lines.

## Setting that holds each bus volume.
var BUS_SETTINGS: Dictionary = {
	"Master": UserSettings.VOLUME_MASTER,
	"Music": UserSettings.VOLUME_MUSIC,
	"SFX": UserSettings.VOLUME_SFX,
	"Weapons": UserSettings.VOLUME_WEAPONS,
	"UI": UserSettings.VOLUME_UI,
	"Alerts": UserSettings.VOLUME_ALERTS,
}

var _config: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _next_3d: int = 0
var _music: AudioStreamPlayer
var _last_played_s: Dictionary = {}  # event or sound id -> time
var _clock_s: float = 0.0
var _hull_was_critical: bool = false
var _muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automated runs stay silent: nobody is listening and tests run headless.
	_muted = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--mute")
	_configure()
	EventBus.data_reloaded.connect(func(_report: DataReport) -> void: _configure())
	UserSettings.changed.connect(_on_setting_changed)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.weapon_overheated.connect(func(_slot: StringName) -> void: play_event("overheat"))
	EventBus.explosion.connect(_on_explosion)
	EventBus.shield_hit.connect(func(_amount: float, _remaining: float) -> void: play_event("shield_hit"))
	EventBus.hull_damaged.connect(_on_hull_damaged)
	EventBus.shield_broken.connect(func() -> void: play_event("shields_down"))
	EventBus.shield_restored.connect(func() -> void: play_event("shields_up"))
	EventBus.power_split_changed.connect(func(_share: float) -> void: play_event("power_tick"))
	EventBus.enemy_projectile_launched.connect(func() -> void: play_event("incoming"))
	EventBus.stage_started.connect(func(_stage: int) -> void: _hull_was_critical = false)
	EventBus.stage_completed.connect(func(_stage: int) -> void: play_event("stage_complete"))
	EventBus.turret_destroyed.connect(func() -> void: play_event("stage_failed"))


func _process(delta_s: float) -> void:
	_clock_s += delta_s


## Plays the sound configured for a named event (see "events" in audio.json).
## `sound_id` overrides the event's own sound (weapons and enemies bring theirs).
## With `at` the sound comes from that place in the world.
func play_event(event_name: String, sound_id: String = "", at: Vector3 = Vector3.INF) -> void:
	var event: Dictionary = (_config.get("events", {}) as Dictionary).get(event_name, {})
	var id: String = sound_id if not sound_id.is_empty() else str(event.get("sound", ""))
	if id.is_empty() or _muted:
		return
	var key: String = event_name + id
	var min_interval_s: float = event.get("min_interval_s", 0.0)
	if _clock_s - float(_last_played_s.get(key, -1000.0)) < min_interval_s:
		return
	_last_played_s[key] = _clock_s
	var stream: AudioStream = GameData.assets.load_asset(id) as AudioStream
	if stream == null:
		return
	var pitch: float = 1.0 + randf_range(-1.0, 1.0) * float(event.get("pitch_random", 0.0))
	var bus: StringName = StringName(str(event.get("bus", "SFX")))
	var volume_db: float = event.get("volume_db", 0.0)
	if at.is_finite():
		var player: AudioStreamPlayer3D = _players_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _players_3d.size()
		player.stream = stream
		player.bus = bus
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.global_position = at
		player.play()
	else:
		var player: AudioStreamPlayer = _players[_next]
		_next = (_next + 1) % _players.size()
		player.stream = stream
		player.bus = bus
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()


## A looping engine sound that follows an enemy, with Doppler shift as it
## flies past. The caller adds the returned node to the enemy; null if the
## sound is unknown or audio is off.
func make_engine_loop(sound_id: String) -> AudioStreamPlayer3D:
	if sound_id.is_empty() or _muted:
		return null
	var stream: AudioStreamWAV = GameData.assets.load_asset(sound_id) as AudioStreamWAV
	if stream == null:
		return null
	if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "EngineSound"
	player.stream = stream
	player.bus = &"SFX"
	player.unit_size = _config.get("engine_unit_size_m", 60.0)
	player.max_distance = _config.get("engine_max_distance_m", 2500.0)
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	player.pitch_scale = randf_range(0.92, 1.08)
	player.autoplay = true
	return player


## Linear volume (0..1) of a bus as the player set it.
func get_bus_volume(bus_name: String) -> float:
	return float(UserSettings.get_value(BUS_SETTINGS.get(bus_name, UserSettings.VOLUME_MASTER)))


func _configure() -> void:
	_config = GameData.loader.get_config("audio")
	var buses: Dictionary = _config.get("buses", {})
	for bus_name: String in buses:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
	_apply_volumes()
	if _players.is_empty():
		for index: int in int(_config.get("players_2d", 20)):
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			add_child(player)
			_players.append(player)
		for index: int in int(_config.get("players_3d", 28)):
			var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			player.unit_size = _config.get("unit_size_m", 120.0)
			player.max_distance = _config.get("max_distance_m", 6000.0)
			add_child(player)
			_players_3d.append(player)
	_start_music()


## Bus volume = the data file's default level, scaled by the player's slider.
func _apply_volumes() -> void:
	var buses: Dictionary = _config.get("buses", {})
	for bus_name: String in buses:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var slider: float = clampf(get_bus_volume(bus_name), 0.0, 1.0)
		AudioServer.set_bus_mute(index, slider <= 0.001)
		AudioServer.set_bus_volume_db(index, float(buses[bus_name]) + linear_to_db(maxf(slider, 0.001)))


func _start_music() -> void:
	var music_id: String = _config.get("music", "")
	if music_id.is_empty() or _muted:
		return
	var stream: AudioStreamWAV = GameData.assets.load_asset(music_id) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.name = "Music"
		_music.bus = &"Music"
		add_child(_music)
	if _music.stream != stream or not _music.playing:
		_music.stream = stream
		_music.play()


func _on_setting_changed(key: String) -> void:
	if key.begins_with("audio/"):
		_apply_volumes()


func _on_weapon_fired(slot: StringName) -> void:
	var turret: Turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	var weapon: Weapon = turret.get_weapon(slot) if turret != null else null
	if weapon != null:
		play_event("weapon_fire", str((weapon.data.get("audio", {}) as Dictionary).get("fire", "")))


func _on_explosion(at: Vector3, radius_m: float) -> void:
	for entry: Dictionary in _config.get("explosion_sounds", []):
		if radius_m <= float(entry.get("up_to_radius_m", 0.0)):
			play_event("explosion", entry.get("sound", ""), at)
			return


func _on_hull_damaged(_amount: float, _remaining: float) -> void:
	play_event("hull_hit")
	var turret: Turret = get_tree().get_first_node_in_group(Turret.GROUP) as Turret
	if turret == null or turret.max_hull <= 0.0:
		return
	var critical: bool = turret.hull / turret.max_hull <= float(_config.get("hull_critical_fraction", 0.3))
	if critical and not _hull_was_critical:
		play_event("hull_critical")
	_hull_was_critical = critical
