extends GdUnitTestSuite
## Contract, project-wide: in every game scene (levels, objects, actors, items) each node in group
## `saveable` implements save_state() and load_state(), and its state round-trips: save_state() of a
## running instance, loaded into a fresh instance, saves the same dictionary (floats within
## tolerance). New components that forget the contract fail here.

const Saves := preload("res://tests/core/save/save_test_helpers.gd")
## Physics frames the first instance runs before its state is taken (props settle, fires tick).
const RUN_FRAMES := 10


func before_test() -> void:
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _scenes(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_scenes(dir_path.path_join(sub), out)
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "tscn":
			out.append(dir_path.path_join(file))


func _instance(path: String) -> Node:
	var node := (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(node)
	return node


func _saveables(root: Node) -> Array[Node]:
	return root.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group(&"saveable")
	)


## Problems found in the scene at `path` (empty: it keeps the contract).
func _check(path: String) -> Array[String]:
	var problems: Array[String] = []
	var first := _instance(path)
	for i in RUN_FRAMES:
		await get_tree().physics_frame
	var saved := {}
	var nodes: Array[Node] = _saveables(first)
	if first.is_in_group(&"saveable"):
		nodes.push_front(first)
	for node in nodes:
		var node_path := String(first.get_path_to(node))
		if not node.has_method(&"save_state") or not node.has_method(&"load_state"):
			problems.append("%s:%s lacks save_state/load_state" % [path, node_path])
			continue
		saved[node_path] = node.call(&"save_state")
	first.free()
	StimulusSystem.clear()
	var second := _instance(path)
	await get_tree().physics_frame
	for node_path: String in saved:
		var node := second.get_node_or_null(NodePath(node_path))
		if node == null:
			problems.append("%s:%s missing in a fresh instance" % [path, node_path])
			continue
		node.call(&"load_state", saved[node_path] as Dictionary)
		var difference := Saves.difference(saved[node_path], node.call(&"save_state"), node_path)
		if not difference.is_empty():
			problems.append("%s: %s" % [path, difference])
	second.free()
	StimulusSystem.clear()
	return problems


func _check_all(root: String) -> void:
	var scenes: Array[String] = []
	_scenes(root, scenes)
	scenes.sort()
	var problems: Array[String] = []
	for path in scenes:
		problems.append_array(await _check(path))
	assert_array(problems).override_failure_message("Saveable contract broken:\n" + "\n".join(problems)).is_empty()


func test_levels_keep_the_saveable_contract() -> void:
	await _check_all("res://levels")


func test_objects_keep_the_saveable_contract() -> void:
	await _check_all("res://objects")


func test_actors_keep_the_saveable_contract() -> void:
	await _check_all("res://actors")


func test_items_keep_the_saveable_contract() -> void:
	await _check_all("res://items")


func test_the_hub_has_saveables_of_every_kind() -> void:
	# Guards the check above against silently finding nothing.
	var hub := _instance("res://levels/hub/hub.tscn")
	await get_tree().physics_frame
	var kinds := {}
	for node in _saveables(hub):
		kinds[(node.get_script() as Script).get_global_name()] = true
	hub.free()

	assert_array(kinds.keys()).contains(
		["Player", "PhysicsObject", "Flammable", "Tags", "Attributes", "BodyParts", "ItemPickup", "PersonalLog"]
	)
