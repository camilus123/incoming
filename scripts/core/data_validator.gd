class_name DataValidator
extends RefCounted
## Cross-file checks that a single-file schema cannot express.
##
## Schemas catch wrong types and ranges. This class catches broken references
## and inconsistent values between fields or files. Each milestone adds its
## checks here (weapon references, tech tree cycles, unreachable nodes, ...).

const REQUIRED_GRAPHICS_PRESETS: PackedStringArray = ["low", "medium", "high", "ultra"]


## Runs every cross-file check on already-loaded data.
static func validate(loader: DataLoader, report: DataReport) -> void:
	_check_power(loader, report)
	_check_turret(loader, report)
	_check_named_default(loader, report, "difficulty", "levels")
	_check_named_default(loader, report, "graphics_presets", "presets")
	_check_graphics_presets(loader, report)
	_check_asset_manifest(loader, report)
	_check_input(loader, report)
	_check_weapons(loader, report)
	_check_loadout(loader, report)
	_check_enemies(loader, report)
	_check_stages(loader, report)
	_check_asset_reference(loader, report, loader.source_of_config("turret"), "model", loader.get_config("turret").get("model", ""))
	_check_asset_reference(loader, report, loader.source_of_config("test_range"), "model", loader.get_config("test_range").get("model", ""))


static func _check_power(loader: DataLoader, report: DataReport) -> void:
	var power: Dictionary = loader.get_config("power")
	if power.is_empty():
		return
	var file: String = loader.source_of_config("power")
	var share: Dictionary = power["shield_share"]
	if share["min"] >= share["max"]:
		report.add_error(file, "shield_share.min", "must be lower than shield_share.max")
	if share["default"] < share["min"] or share["default"] > share["max"]:
		report.add_error(file, "shield_share.default", "must lie between shield_share.min and shield_share.max")


static func _check_turret(loader: DataLoader, report: DataReport) -> void:
	var turret: Dictionary = loader.get_config("turret")
	if turret.is_empty():
		return
	var file: String = loader.source_of_config("turret")
	var aim: Dictionary = turret["aim"]
	if aim["yaw_min_deg"] >= aim["yaw_max_deg"]:
		report.add_error(file, "aim.yaw_min_deg", "must be lower than aim.yaw_max_deg")
	if aim["pitch_min_deg"] >= aim["pitch_max_deg"]:
		report.add_error(file, "aim.pitch_min_deg", "must be lower than aim.pitch_max_deg")


## Checks that `config.default` names an existing key of `config[group_field]`.
static func _check_named_default(loader: DataLoader, report: DataReport, config_name: String, group_field: String) -> void:
	var config: Dictionary = loader.get_config(config_name)
	if config.is_empty():
		return
	var group: Dictionary = config[group_field]
	var default_name: String = config["default"]
	if not group.has(default_name):
		report.add_error(loader.source_of_config(config_name), "default", "\"%s\" is not defined in %s" % [default_name, group_field])


static func _check_graphics_presets(loader: DataLoader, report: DataReport) -> void:
	var config: Dictionary = loader.get_config("graphics_presets")
	if config.is_empty():
		return
	var presets: Dictionary = config["presets"]
	for preset_name: String in REQUIRED_GRAPHICS_PRESETS:
		if not presets.has(preset_name):
			report.add_error(loader.source_of_config("graphics_presets"), "presets." + preset_name, "required preset is missing or invalid")


static func _check_asset_manifest(loader: DataLoader, report: DataReport) -> void:
	var manifest: Dictionary = loader.get_config("asset_manifest")
	if manifest.is_empty():
		return
	var file: String = loader.source_of_config("asset_manifest")
	var assets: Dictionary = manifest["assets"]
	for asset_id: String in assets:
		var asset: Dictionary = assets[asset_id]
		var path: String = asset["path"]
		if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			report.add_error(file, "assets.%s.path" % asset_id, "file does not exist: %s" % path)
		var fallback: String = asset.get("fallback", "")
		if not fallback.is_empty() and not assets.has(fallback):
			report.add_error(file, "assets.%s.fallback" % asset_id, "unknown asset id \"%s\"" % fallback)


static func _check_input(loader: DataLoader, report: DataReport) -> void:
	var config: Dictionary = loader.get_config("input")
	var file: String = loader.source_of_config("input")
	var actions: Dictionary = config.get("actions", {})
	for action_name: String in actions:
		var events: Array = actions[action_name]["events"]
		for index: int in events.size():
			var event: Dictionary = events[index]
			var field: String = "actions.%s.events[%d]" % [action_name, index]
			if event.has("key") == event.has("mouse_button"):
				report.add_error(file, field, "needs exactly one of \"key\" or \"mouse_button\"")
			elif event.has("key") and OS.find_keycode_from_string(event["key"]) == KEY_NONE:
				report.add_error(file, field + ".key", "unknown key name \"%s\"" % event["key"])


static func _check_weapons(loader: DataLoader, report: DataReport) -> void:
	var weapons: Dictionary = loader.get_category("weapons")
	for weapon_id: String in weapons:
		var weapon: Dictionary = weapons[weapon_id]
		var file: String = loader.source_of("weapons", weapon_id)
		var archetype: String = weapon["archetype"]
		if not WeaponArchetypes.IMPLEMENTED.has(archetype):
			report.add_warning(file, "archetype", "archetype \"%s\" is not implemented yet; the weapon cannot be equipped" % archetype)
		if archetype == "homing" and not weapon.has("homing"):
			report.add_error(file, "homing", "a homing weapon needs a \"homing\" block")
		var visuals: Dictionary = weapon["visuals"]
		_check_asset_reference(loader, report, file, "visuals.model", visuals["model"])
		_check_asset_reference(loader, report, file, "visuals.projectile_model", visuals["projectile_model"])
		var audio: Dictionary = weapon.get("audio", {})
		for sound_key: String in audio:
			_check_asset_reference(loader, report, file, "audio." + sound_key, audio[sound_key])


static func _check_loadout(loader: DataLoader, report: DataReport) -> void:
	var turret: Dictionary = loader.get_config("turret")
	if turret.is_empty():
		return
	var file: String = loader.source_of_config("turret")
	var loadout: Dictionary = turret["default_loadout"]
	for slot: String in loadout:
		var weapon_id: String = loadout[slot]
		if not loader.has_entry("weapons", weapon_id):
			report.add_error(file, "default_loadout." + slot, "unknown weapon \"%s\"" % weapon_id)
		elif not (loader.get_entry("weapons", weapon_id)["allowed_slots"] as Array).has(slot):
			report.add_error(file, "default_loadout." + slot, "weapon \"%s\" is not allowed in the %s slot" % [weapon_id, slot])


## Reports an error if a non-empty asset ID is not in the asset manifest.
static func _check_asset_reference(loader: DataLoader, report: DataReport, file: String, field: String, asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var assets: Dictionary = loader.get_config("asset_manifest").get("assets", {})
	if not assets.has(asset_id):
		report.add_error(file, field, "unknown asset id \"%s\" (not in the asset manifest)" % asset_id)

static func _check_enemies(loader: DataLoader, report: DataReport) -> void:
	var behaviours: Dictionary = loader.get_category("behaviours")
	for behaviour_id: String in behaviours:
		var module_name: String = behaviours[behaviour_id]["module"]
		if not BehaviourModules.IMPLEMENTED.has(module_name):
			report.add_error(loader.source_of("behaviours", behaviour_id), "module", "unknown behaviour module \"%s\"" % module_name)
	var enemies: Dictionary = loader.get_category("enemies")
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		var file: String = loader.source_of("enemies", enemy_id)
		_check_asset_reference(loader, report, file, "model", enemy["model"])
		var listed: Array = enemy["behaviours"]
		for index: int in listed.size():
			if not behaviours.has(listed[index]):
				report.add_error(file, "behaviours[%d]" % index, "unknown behaviour \"%s\"" % listed[index])
		var group_size: Array = enemy["group_size"]
		if group_size[0] > group_size[1]:
			report.add_error(file, "group_size", "the first value must not be larger than the second")
		var attacks: Array = enemy["attacks"]
		for index: int in attacks.size():
			var attack: Dictionary = attacks[index]
			if attack["type"] == "guided_bomb":
				if not attack.has("projectile"):
					report.add_error(file, "attacks[%d].projectile" % index, "a guided_bomb attack needs a \"projectile\" block")
				else:
					_check_asset_reference(loader, report, file, "attacks[%d].projectile.model" % index, attack["projectile"]["model"])


static func _check_stages(loader: DataLoader, report: DataReport) -> void:
	var enemies: Dictionary = loader.get_category("enemies")
	var stages: Dictionary = loader.get_category("stages")
	var seen_numbers: Dictionary = {}
	for stage_id: String in stages:
		var stage: Dictionary = stages[stage_id]
		var file: String = loader.source_of("stages", stage_id)
		var number: int = stage["stage"]
		if stage_id != "stage_%02d" % number:
			report.add_error(file, "id", "must be \"stage_%02d\" to match \"stage\": %d" % [number, number])
		if seen_numbers.has(number):
			report.add_error(file, "stage", "stage %d is also defined in %s" % [number, seen_numbers[number]])
		seen_numbers[number] = file
		var waves: Array = stage["waves"]
		for wave_index: int in waves.size():
			var wave: Dictionary = waves[wave_index]
			var field: String = "waves[%d]" % wave_index
			var groups: Array = wave["groups"]
			if groups.is_empty() and float(wave["budget_share"]) <= 0.0:
				report.add_error(file, field, "a wave needs \"groups\" or a \"budget_share\" above 0")
			for group_index: int in groups.size():
				_check_stage_enemy(report, file, "%s.groups[%d].enemy" % [field, group_index], groups[group_index]["enemy"], number, enemies)
			var listed: Array = wave["enemies"]
			for enemy_index: int in listed.size():
				_check_stage_enemy(report, file, "%s.enemies[%d]" % [field, enemy_index], listed[enemy_index], number, enemies)
	# Authored stages must be numbered 1..N without gaps.
	for number: int in range(1, seen_numbers.size() + 1):
		if not seen_numbers.has(number):
			report.add_error(loader.source_of_config("director").get_base_dir(), "", "stage %d is missing (stages must be numbered without gaps)" % number)


static func _check_stage_enemy(report: DataReport, file: String, field: String, enemy_id: String, stage_number: int, enemies: Dictionary) -> void:
	if not enemies.has(enemy_id):
		report.add_error(file, field, "unknown enemy \"%s\"" % enemy_id)
	elif int(enemies[enemy_id]["first_stage"]) > stage_number:
		report.add_warning(file, field, "enemy \"%s\" is used before its first_stage (%d)" % [enemy_id, int(enemies[enemy_id]["first_stage"])])