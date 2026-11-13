extends GdUnitTestSuite
## Level data (S16, ADR 0140): no shipped device, door, readable or pickup shows a node name to the
## player. A device or door entity has `display_name` metadata (EntityNames: what the deck's Map,
## name plates and the interaction frame show); a door controller is named after its door at bind
## time (DoorController.bind()), so its door is checked; a readable has a title and a `source` (the
## Journal's "from"); a pickup's item has a display name. The shipped levels are instantiated out of
## the tree (no _ready runs) and every offender is listed.

const LEVELS: Array[String] = ["res://levels/hub/hub.tscn", "res://levels/mission/warehouse.tscn"]


func test_shipped_content_never_falls_back_to_a_node_name() -> void:
	var offenders: Array[String] = []
	for path in LEVELS:
		var root := (load(path) as PackedScene).instantiate()
		_check(root, root, path.get_file(), offenders)
		root.free()
	assert_array(offenders).is_empty()


func _check(root: Node, node: Node, level: String, offenders: Array[String]) -> void:
	var why := _fallback(node)
	if not why.is_empty():
		offenders.append("%s: %s (%s)" % [level, root.get_path_to(node), why])
	for child in node.get_children():
		_check(root, child, level, offenders)


# Why `node` would show a node name to the player, or "".
static func _fallback(node: Node) -> String:
	var has_name := node.has_meta(EntityNames.META)
	var device := false
	var door := false
	for child in node.get_children():
		if child is DoorController:
			return ""
		if child is Device:
			device = true
		elif child is Door:
			door = true
		elif child is Readable:
			var readable := child as Readable
			if readable.title.is_empty():
				return "readable without a title"
			if readable.source.is_empty():
				return "readable without a source"
		elif child is ItemPickup:
			var pickup := child as ItemPickup
			if pickup.item == null or pickup.item.display_name.is_empty():
				return "pickup without an item name"
	if device and not has_name:
		return "device without a display_name"
	if door and not has_name:
		return "door without a display_name"
	return ""
