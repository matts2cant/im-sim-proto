class_name LevelSnapshot
extends RefCounted
## Captures and restores the saveable state of a level instance (ADR 0063).
## A snapshot has three parts, all node paths relative to the level root:
## - `states`: path -> save_state() of every node in group `saveable` under the level.
## - `removed`: level-placed entities (in the level's packed scene, with a saveable in their
##   subtree) that no longer exist: broken crates, exploded barrels, burnt barricades, consumed
##   pickups. Only the topmost missing node of each is listed.
## - `spawned`: path -> scene file of each entity root that is not in the packed scene (dropped
##   pickups, debug-spawned objects, broken-crate contents): the topmost ancestor of a saveable
##   whose path is not in the packed scene. Its parent always is.
## What the packed scene contains comes from `packed_index()`: the scene instantiated once out of
## the tree (no _ready runs), every node's path and scene file listed, then freed; cached per scene.
## A live node counts as level-placed only when its path is in the index with the same scene file,
## so a spawned node that took the name of a removed one is still saved as spawned.
## Nodes without saveables (Debris, fire and explosion effects, sounds) are not saved.

const GROUP: StringName = &"saveable"

## Level scene path -> PackedIndex.
static var _index_cache: Dictionary[String, PackedIndex] = {}


## What a level's packed scene contains.
class PackedIndex:
	extends RefCounted
	## Node path -> scene_file_path ("" for nodes that are not scene instances).
	var scenes: Dictionary[String, String] = {}
	## Paths whose subtree (the node included) has a node with save_state(), parents first.
	var saveable_roots: Array[String] = []

	func is_placed(path: String, node: Node) -> bool:
		return scenes.has(path) and scenes[path] == node.scene_file_path


## Result of apply().
class Report:
	extends RefCounted
	## Saved paths that could not be restored (the level changed since the save); each was
	## pushed as a warning.
	var skipped: Array[String] = []
	## A removed node took level geometry with it (a static body or CSG collider): derived data
	## such as the navmesh must be rebuilt.
	var geometry_removed: bool = false


static func packed_index(scene_path: String) -> PackedIndex:
	if _index_cache.has(scene_path):
		return _index_cache[scene_path]
	var index := PackedIndex.new()
	var packed := load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
	if packed != null:
		var root := packed.instantiate()
		_index_node(root, root, index)
		root.free()
		index.saveable_roots.sort()
	_index_cache[scene_path] = index
	return index


## The level's saveable state (see the class description).
static func capture(level: Node) -> Dictionary:
	var index := packed_index(level.scene_file_path)
	var states := {}
	var spawned := {}
	for node in _saveables(level):
		if not node.has_method(&"save_state") or not node.has_method(&"load_state"):
			push_warning("LevelSnapshot: %s is in group saveable without the contract" % node.get_path())
			continue
		states[String(level.get_path_to(node))] = node.call(&"save_state")
		var root := _spawned_root(level, node, index)
		if root != null:
			spawned[String(level.get_path_to(root))] = root.scene_file_path
	return {"states": states, "removed": _removed(level, index), "spawned": spawned}


## True when `snapshot` has the three parts with the right types (a save read from disk).
static func is_valid(snapshot: Dictionary) -> bool:
	return (
		snapshot.get("states") is Dictionary
		and snapshot.get("removed") is Array
		and snapshot.get("spawned") is Dictionary
	)


## Restores a snapshot onto a freshly loaded instance of the same level: frees the removed nodes,
## recreates the spawned ones (from their scene, under the same parent, with the same name), then
## calls load_state() in tree order (pre-order: parents before children, siblings in tree order).
static func apply(level: Node, snapshot: Dictionary) -> Report:
	var report := Report.new()
	var removed: Array = snapshot.get("removed", [])
	for path: Variant in removed:
		var node := level.get_node_or_null(NodePath(str(path)))
		if node == null or node == level:
			_skip(report, str(path), "removed node not found")
			continue
		if _has_geometry(node):
			report.geometry_removed = true
		node.get_parent().remove_child(node)
		node.free()
	var spawned: Dictionary = snapshot.get("spawned", {})
	var spawned_paths: Array = spawned.keys()
	spawned_paths.sort()
	for path: Variant in spawned_paths:
		_respawn(level, str(path), str(spawned[path]), report)
	var states: Dictionary = snapshot.get("states", {})
	var applied := {}
	for node in _saveables(level):
		var path := String(level.get_path_to(node))
		if states.get(path) is Dictionary and node.has_method(&"load_state"):
			node.call(&"load_state", states[path])
			applied[path] = true
	for path: Variant in states:
		if not applied.has(path):
			_skip(report, str(path), "saved node not found")
	return report


## Nodes in group saveable under `level` (itself included), in tree pre-order.
static func _saveables(level: Node) -> Array[Node]:
	var out: Array[Node] = []
	_collect(level, out)
	return out


static func _collect(node: Node, out: Array[Node]) -> void:
	if node.is_queued_for_deletion():
		return
	if node.is_in_group(GROUP):
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


static func _index_node(root: Node, node: Node, index: PackedIndex) -> bool:
	var has_saveable := node.has_method(&"save_state")
	for child in node.get_children(true):
		if _index_node(root, child, index):
			has_saveable = true
	var path := String(root.get_path_to(node))
	index.scenes[path] = node.scene_file_path
	if has_saveable and node != root:
		index.saveable_roots.append(path)
	return has_saveable


# The topmost ancestor of `node` (itself included) that is not level-placed; null when it is.
static func _spawned_root(level: Node, node: Node, index: PackedIndex) -> Node:
	var top: Node = null
	var current := node
	while current != level and not index.is_placed(String(level.get_path_to(current)), current):
		top = current
		current = current.get_parent()
	return top


static func _removed(level: Node, index: PackedIndex) -> Array[String]:
	var removed: Array[String] = []
	for path in index.saveable_roots:
		if _under_any(path, removed):
			continue
		var node := level.get_node_or_null(NodePath(path))
		if node == null or node.is_queued_for_deletion() or not index.is_placed(path, node):
			removed.append(path)
	return removed


static func _under_any(path: String, roots: Array[String]) -> bool:
	for root in roots:
		if path.begins_with(root + "/"):
			return true
	return false


static func _respawn(level: Node, path: String, scene_path: String, report: Report) -> void:
	var node_path := NodePath(path)
	if level.has_node(node_path):
		return  # Already there: made by the level itself.
	var parent_path := path.get_base_dir() if path.contains("/") else "."
	var parent := level.get_node_or_null(NodePath(parent_path))
	if parent == null or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		_skip(report, path, "cannot recreate spawned node (scene '%s')" % scene_path)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_skip(report, path, "spawned scene '%s' is not a scene" % scene_path)
		return
	var node := packed.instantiate()
	node.name = path.get_file()
	parent.add_child(node)
	if String(node.name) != path.get_file():
		_skip(report, path, "spawned node was renamed to %s" % node.name)


static func _has_geometry(node: Node) -> bool:
	if node is StaticBody3D:
		return true
	if node is CSGShape3D and (node as CSGShape3D).use_collision:
		return true
	for child in node.get_children():
		if _has_geometry(child):
			return true
	return false


static func _skip(report: Report, path: String, reason: String) -> void:
	report.skipped.append(path)
	push_warning("LevelSnapshot: %s skipped: %s" % [path, reason])
