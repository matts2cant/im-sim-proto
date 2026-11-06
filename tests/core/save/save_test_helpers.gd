extends RefCounted
## Test helper (not a suite) for save tests: a test save slot, a level made the tree's current
## scene (a load changes the current scene), key presses, waiting for a load, and a
## tolerant comparison of saved dictionaries.

## Tests never touch the player's real save.
const SLOT := "user://test_saves/quicksave.save"
const TOLERANCE := 0.0005


## Points QuickSave at the test slot and deletes it.
static func use_test_slot() -> void:
	QuickSave.path = SLOT
	delete_slot()


static func delete_slot() -> void:
	if FileAccess.file_exists(SLOT):
		DirAccess.remove_absolute(SLOT)


static func write_slot(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SLOT.get_base_dir())
	var file := FileAccess.open(SLOT, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Instances `path` under the root as the current scene and lets it settle (CSG collision).
static func open_level(tree: SceneTree, path: String, settle: int = 10) -> Node:
	var level := (load(path) as PackedScene).instantiate()
	tree.root.add_child(level)
	tree.current_scene = level
	for i in settle:
		await tree.physics_frame
	return level


## Frees the current scene (the level, or the one a load made) and restores `original`.
static func close_level(tree: SceneTree, original: Node) -> void:
	var current := tree.current_scene
	tree.current_scene = original
	if current != null and current != original and is_instance_valid(current):
		current.free()
	QuickSave.path = QuickSave.DEFAULT_PATH
	delete_slot()
	PauseScreens.reset(tree)
	tree.paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A key press and release. Both the physical and the logical keycode are set, so actions bound
## either way match (the project binds physical keys; the built-in ui_* actions logical ones).
static func press(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## Waits until a load started from `old_level` has finished; returns the new level (null if
## nothing was loaded within `max_frames`).
static func wait_for_load(tree: SceneTree, old_level: Node, max_frames: int = 60) -> Node:
	for i in max_frames:
		await tree.process_frame
		if tree.current_scene != old_level and not QuickSave.is_loading():
			return tree.current_scene
	return null


## Path of the first difference between two saved values ("" when equal); floats, vectors and
## transforms within TOLERANCE.
static func difference(a: Variant, b: Variant, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return "%s: keys %s vs %s" % [path, da.keys(), db.keys()]
		for key: Variant in da:
			if not db.has(key):
				return "%s/%s: missing" % [path, key]
			var inner := difference(da[key], db[key], "%s/%s" % [path, key])
			if not inner.is_empty():
				return inner
		return ""
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return "%s: size %d vs %d" % [path, aa.size(), ab.size()]
		for i in aa.size():
			var inner := difference(aa[i], ab[i], "%s[%d]" % [path, i])
			if not inner.is_empty():
				return inner
		return ""
	if (a is float or a is int) and (b is float or b is int) and (a is float or b is float):
		return "" if absf(float(a) - float(b)) <= TOLERANCE else "%s: %s vs %s" % [path, a, b]
	if a is Vector3 and b is Vector3:
		return "" if ((a as Vector3) - (b as Vector3)).length() <= TOLERANCE else "%s: %s vs %s" % [path, a, b]
	if a is Transform3D and b is Transform3D:
		var ta: Transform3D = a
		var tb: Transform3D = b
		var close := (ta.origin - tb.origin).length() <= TOLERANCE
		for axis in 3:
			close = close and (ta.basis[axis] - tb.basis[axis]).length() <= TOLERANCE
		return "" if close else "%s: %s vs %s" % [path, a, b]
	if typeof(a) != typeof(b) and not (a is String or a is StringName) and not (b is String or b is StringName):
		return "%s: type %d vs %d" % [path, typeof(a), typeof(b)]
	return "" if a == b else "%s: %s vs %s" % [path, a, b]
