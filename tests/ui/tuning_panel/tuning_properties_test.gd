extends GdUnitTestSuite
## TuningProperties (ADR 0125): by reflection only, a weapon and the scripted resources it
## references, their `@export_range` floats and ints as sliders (test resources whose names the
## code never sees), live changes, and Save / Revert through the files (user:// here).

const TestWeapon := preload("res://tests/ui/tuning_panel/fixtures/tuning_test_weapon.gd")
const TestPart := preload("res://tests/ui/tuning_panel/fixtures/tuning_test_part.gd")
const AIM: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const PATH := "user://m13a_tuning_properties_test.tres"


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_entries_are_the_weapon_and_the_resources_it_references() -> void:
	var weapon := _weapon()
	weapon.aim_config = AIM
	weapon.scope_aim_config = AIM

	var entries := TuningProperties.entries(weapon)

	var labels: Array[String] = []
	for entry in entries:
		labels.append(entry.label)
	# The aim config once, although two properties reference it; no PackedScene or audio.
	assert_array(labels).contains_exactly_in_any_order(["", "aim_config", "part"])
	assert_object(entries[0].resource).is_same(weapon)


func test_sliders_are_the_range_floats_and_ints() -> void:
	var weapon := _weapon()

	var names := _names(TuningProperties.sliders(weapon))

	assert_array(names).contains(["kick", "burst"])
	# No range hint: not a slider.
	assert_array(names).not_contains(["plain", "cycle_time", "fire_noise"])
	var kick := _find(TuningProperties.sliders(weapon), "kick")
	assert_float(kick.min_value).is_equal(0.0)
	assert_float(kick.max_value).is_equal(5.0)
	assert_float(kick.step).is_equal_approx(0.1, 0.0001)
	var burst := _find(TuningProperties.sliders(weapon), "burst")
	assert_int(burst.type).is_equal(TYPE_INT)
	assert_array(_names(TuningProperties.sliders(weapon.part))).contains_exactly(["climb"])


func test_set_value_changes_the_live_resource() -> void:
	var weapon := _weapon()
	var changed := [false]
	weapon.changed.connect(func() -> void: changed[0] = true)

	TuningProperties.set_value(weapon, _find(TuningProperties.sliders(weapon), "kick"), 2.5)
	TuningProperties.set_value(weapon, _find(TuningProperties.sliders(weapon), "burst"), 6.6)

	assert_float(weapon.kick).is_equal_approx(2.5, 0.0001)
	assert_int(weapon.burst).is_equal(7)
	assert_bool(changed[0]).is_true()


func test_save_writes_the_file_and_revert_reads_it_back() -> void:
	var weapon := _saved_weapon()
	weapon.kick = 3.0
	weapon.part.climb = 9.5

	assert_array(Array(TuningProperties.save(weapon))).is_empty()

	var on_disk := ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_float(on_disk.get("kick")).is_equal_approx(3.0, 0.0001)
	assert_float((on_disk.get("part") as Resource).get("climb")).is_equal_approx(9.5, 0.0001)
	# Changed again, then reverted: the saved values come back, the embedded part's too.
	weapon.kick = 0.5
	weapon.part.climb = 1.0
	assert_int(TuningProperties.revert(weapon)).is_equal(2)
	assert_float(weapon.kick).is_equal_approx(3.0, 0.0001)
	assert_float(weapon.part.climb).is_equal_approx(9.5, 0.0001)


func test_resources_without_a_file_cannot_be_saved_or_reverted() -> void:
	var weapon := _weapon()

	assert_array(Array(TuningProperties.save(weapon))).is_empty()
	assert_int(TuningProperties.revert(weapon)).is_equal(0)


func _weapon() -> TestWeapon:
	var weapon := TestWeapon.new()
	weapon.id = &"test_gun"
	weapon.part = TestPart.new()
	return weapon


# A weapon saved to PATH (its part embedded) and loaded back, so it knows its file.
func _saved_weapon() -> TestWeapon:
	assert_int(ResourceSaver.save(_weapon(), PATH)).is_equal(OK)
	return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as TestWeapon


static func _names(sliders: Array[TuningProperties.RangeProperty]) -> Array[String]:
	var names: Array[String] = []
	for slider in sliders:
		names.append(slider.name)
	return names


static func _find(sliders: Array[TuningProperties.RangeProperty], property: String) -> TuningProperties.RangeProperty:
	for slider in sliders:
		if slider.name == property:
			return slider
	return null
