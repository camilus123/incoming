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
