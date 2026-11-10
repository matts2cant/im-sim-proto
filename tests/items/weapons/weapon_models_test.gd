extends GdUnitTestSuite
## Data rule: every held weapon (not melee) shows a model, not the grey box fallback, so a guard or
## the player never holds a box by a missing `view_scene`.

const ROOT := "res://items/weapons"


func test_every_non_melee_weapon_data_has_a_view_scene() -> void:
	var checked := 0
	var missing: Array[String] = []
	for path in _tres_files(ROOT):
		var weapon := load(path) as WeaponData
		if weapon == null:
			continue
		checked += 1
		if not weapon.is_melee() and weapon.view_scene == null:
			missing.append(path)

	assert_int(checked).is_greater(3)
	assert_array(missing).is_empty()


func _tres_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_tres_files(dir_path.path_join(sub)))
	return found
