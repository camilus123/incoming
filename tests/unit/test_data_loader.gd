extends GutTest
## Tests for DataLoader and DataValidator against the real data and a broken fixture.

const BAD_ROOT: String = "res://tests/fixtures/bad_data"


func test_shipped_data_is_valid() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all()
	DataValidator.validate(loader, report)
	assert_eq(report.error_count(), 0, report.format_text())
	assert_eq(report.warning_count(), 0, report.format_text())


func test_power_config_matches_the_spec_defaults() -> void:
	var loader: DataLoader = DataLoader.new()
	loader.load_all()
	var power: Dictionary = loader.get_config("power")
	assert_almost_eq(float(power["shield_share"]["default"]), 0.5, 0.0001)
	assert_almost_eq(float(power["shield_share"]["step"]), 0.1, 0.0001)
	assert_almost_eq(float(power["shield_recharge_multiplier"]["at_full_share"]), 2.0, 0.0001)
	assert_almost_eq(float(power["weapon_output_multiplier"]["at_zero_share"]), 0.5, 0.0001)


func test_missing_data_root_reports_instead_of_crashing() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all("res://does_not_exist")
	assert_true(report.has_errors())
	assert_eq(loader.get_config("power"), {})


func test_broken_configs_fall_back_to_schema_defaults() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all(BAD_ROOT)
	assert_true(report.has_issue_containing("invalid JSON"))
	assert_true(report.has_issue_containing("file not found"))
	for config_name: String in ["broken", "wrong_types", "missing"]:
		var config: Dictionary = loader.get_config(config_name)
		assert_eq(config.get("speed"), 10.0, config_name)
		assert_eq(config.get("name"), "fallback", config_name)


func test_bad_collection_entries_are_skipped() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all(BAD_ROOT)
	var things: Dictionary = loader.get_category("things")
	assert_eq(things.size(), 1)
	assert_true(loader.has_entry("things", "alpha"))
	assert_eq(loader.get_entry("things", "alpha")["hp"], 5.0)
	assert_true(report.has_issue_containing("required field is missing"))
	assert_true(report.has_issue_containing("duplicate id"))
	assert_true(report.has_issue_containing("expected a number"))


func test_report_names_file_and_field() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all(BAD_ROOT)
	var found: bool = false
	for issue: Dictionary in report.get_issues():
		if str(issue["file"]).ends_with("things/beta.json") and issue["field"] == "hp":
			found = true
	assert_true(found, report.format_text())


func test_validator_catches_cross_field_errors() -> void:
	var loader: DataLoader = DataLoader.new()
	var report: DataReport = loader.load_all()
	var turret: Dictionary = loader.get_config("turret")
	turret["aim"]["yaw_min_deg"] = 10.0
	turret["aim"]["yaw_max_deg"] = 5.0
	loader.get_config("difficulty")["default"] = "nightmare"
	DataValidator.validate(loader, report)
	assert_true(report.has_issue_containing("must be lower than aim.yaw_max_deg"))
	assert_true(report.has_issue_containing("\"nightmare\" is not defined"))
