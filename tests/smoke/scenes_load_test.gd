extends GdUnitTestSuite
## Smoke: every gameplay scene loads and instantiates (catches references to deleted or moved resources).

const ROOTS: Array[String] = ["res://levels", "res://actors", "res://objects", "res://items", "res://ui"]


func _collect(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "tscn":
			out.append(dir_path.path_join(file))


func test_all_scenes_load_and_instantiate() -> void:
	var scenes: Array[String] = []
	for root in ROOTS:
		_collect(root, scenes)
	scenes.sort()
	assert_int(scenes.size()).is_greater(0)
	var failures: Array[String] = []
	for path in scenes:
		var res := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
		var packed := res as PackedScene
		if packed == null:
			failures.append("%s: failed to load" % path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			failures.append("%s: instantiate() returned null" % path)
			continue
		inst.free()
	assert_array(failures).override_failure_message("Broken scenes:\n" + "\n".join(failures)).is_empty()
