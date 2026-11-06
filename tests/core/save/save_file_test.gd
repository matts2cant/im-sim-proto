extends GdUnitTestSuite
## Unit: the save file format (SaveFile): Godot types survive, bad files are refused without errors.

const DIR := "user://test_saves/save_file"


func after_test() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))


func _header() -> Dictionary:
	return {"version": SaveFile.VERSION, "level": "res://levels/hub/hub.tscn", "saved_at": "2026-11-06T12:00:00"}


func test_godot_types_survive_a_round_trip() -> void:
	var typed: Array[Dictionary] = [{"a": 1}]
	var data := _header()
	data["states"] = {
		"Player":
		{
			"position": Vector3(1.5, 0.25, -3.0),
			"transform": Transform3D(Basis.from_euler(Vector3(0.1, 0.7, 0.0)), Vector3(4, 5, 6)),
			"tag": &"state.burning",
			"count": 3,
			"heat": 2.5,
			"list": typed,
			"by_int": {7: "seven"},
		}
	}

	var result := SaveFile.decode(SaveFile.encode(data))

	assert_int(result.status).is_equal(SaveFile.Status.OK)
	var player: Dictionary = (result.data["states"] as Dictionary)["Player"]
	assert_int(typeof(player["position"])).is_equal(TYPE_VECTOR3)
	assert_vector(player["position"] as Vector3).is_equal(Vector3(1.5, 0.25, -3.0))
	var expected: Transform3D = data["states"]["Player"]["transform"]
	assert_bool((player["transform"] as Transform3D).is_equal_approx(expected)).is_true()
	assert_int(typeof(player["tag"])).is_equal(TYPE_STRING_NAME)
	assert_int(typeof(player["count"])).is_equal(TYPE_INT)
	assert_int(typeof(player["heat"])).is_equal(TYPE_FLOAT)
	assert_bool((player["list"] as Array).is_typed()).is_true()
	assert_str(str((player["by_int"] as Dictionary)[7])).is_equal("seven")


func test_text_is_not_parsed_into_objects() -> void:
	# var_to_str's Object(...) syntax is not a save: it never instantiates anything.
	var text := 'Object(Node,"name":"Evil","script":null)'

	assert_int(SaveFile.decode(text).status).is_equal(SaveFile.Status.CORRUPT)


func test_garbage_and_wrong_shapes_are_corrupt() -> void:
	assert_int(SaveFile.decode("{not json").status).is_equal(SaveFile.Status.CORRUPT)
	assert_int(SaveFile.decode("").status).is_equal(SaveFile.Status.CORRUPT)
	assert_int(SaveFile.decode(SaveFile.encode({"version": SaveFile.VERSION})).status).is_equal(SaveFile.Status.CORRUPT)
	var truncated := SaveFile.encode(_header())
	assert_int(SaveFile.decode(truncated.substr(0, truncated.length() / 2)).status).is_equal(SaveFile.Status.CORRUPT)


func test_another_version_is_refused() -> void:
	var data := _header()
	data["version"] = SaveFile.VERSION + 1

	assert_int(SaveFile.decode(SaveFile.encode(data)).status).is_equal(SaveFile.Status.WRONG_VERSION)


func test_write_then_read_fills_the_header() -> void:
	var path := DIR.path_join("slot.save")

	var status := SaveFile.write(path, "res://levels/hub/hub.tscn", {"states": {"A": {"x": 1}}})
	var result := SaveFile.read(path)

	assert_int(status).is_equal(SaveFile.Status.OK)
	assert_int(result.status).is_equal(SaveFile.Status.OK)
	assert_int(result.data["version"]).is_equal(SaveFile.VERSION)
	assert_str(result.data["level"]).is_equal("res://levels/hub/hub.tscn")
	assert_str(result.data["saved_at"]).is_not_empty()
	assert_int((result.data["states"] as Dictionary)["A"]["x"]).is_equal(1)


func test_missing_file() -> void:
	assert_int(SaveFile.read(DIR.path_join("none.save")).status).is_equal(SaveFile.Status.MISSING)
