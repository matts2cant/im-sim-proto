extends GdUnitTestSuite
## Shooting range M14c areas (ADR 0131) in the room fixture (the room, the player and a navmesh of
## the room alone, fixtures/range_player.tscn): from the hub doorway (the range corridor's mouth) the
## navmesh leads to the grenade table, the throwing line, the target, the mine corridor and the EMP
## room (through the corridor's door), and the player walks from the hall through the mine corridor
## and its door into the EMP room (flat floors: nothing to climb). In the hub scene (instanced, not
## run), every other electronic device stands beyond a jamming field's reach (10 m) of the EMP
## room's: the nearest, the security wing's, 12.5 m away.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const JAMMING: Resource = preload("res://objects/explosives/jamming_field/jamming_field.tres")
const FIXTURE := "res://tests/levels/gallery/shooting_range/fixtures/range_player.tscn"
const HUB: PackedScene = preload("res://levels/hub/hub.tscn")
## Room-local points (origin on the hub wall's outer face, -Z away from the hub).
const DOORWAY := Vector3(0, 0, -0.5)
const NAV_POINTS: Dictionary[String, Vector3] = {
	"grenade table": Vector3(12.5, 0, -25.0),
	"throwing line": Vector3(13.0, 0, -27.6),
	"target": Vector3(13.0, 0, -39.0),
	"mine corridor": Vector3(24.0, 0, -12.5),
	"EMP room": Vector3(32.0, 0, -11.0),
}

var _driver: PlayerDriver
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_from_the_doorway_to_every_area_and_through_the_mine_corridor() -> void:
	_driver = PlayerDriver.new(scene_runner(FIXTURE))
	_room = _driver.runner.find_child("ShootingRangeRoom") as Node3D
	var nav := _driver.runner.find_child("Navigation") as LevelNavigation
	await _driver.settle()
	var map := nav.get_navigation_map()
	var doorway := _room.to_global(DOORWAY)
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, doorway)).is_true()

	for area: String in NAV_POINTS:
		var target := _room.to_global(NAV_POINTS[area])
		var path := NavigationServer3D.map_get_path(map, doorway, target, true)
		assert_bool(path.is_empty()).override_failure_message(area).is_false()
		assert_float(path[-1].distance_to(target)).override_failure_message(area).is_less(0.3)

	# The real player: from the hall through the corridor and its opened door into the EMP room.
	var door := _room.get_node("MineCorridor/Door/Door") as Door
	var east := _room.global_basis * Vector3.RIGHT
	await _driver.place(_room.to_global(Vector3(19.0, 0, -12.5)), atan2(-east.x, -east.z))
	door.open(_driver.player)
	await _driver.hold(&"move_forward", 200)

	var feet := _room.to_local(_driver.player.global_position)
	assert_float(feet.x).is_greater(29.0)
	assert_float(absf(feet.z + 12.5)).is_less(0.5)
	assert_float(feet.y).is_equal_approx(0.0, 0.05)


func test_no_other_device_in_the_hub_within_jamming_reach_of_the_emp_room() -> void:
	var hub := HUB.instantiate()
	var room := hub.get_node("ShootingRangeRoom")
	var corner := room.get_node("EmpCorner")
	var corner_points: Array[Vector3] = []
	for device: Node in corner.get_children():
		corner_points.append(_hub_position(device, hub))
	var nearest := INF
	for node: Node in hub.find_children("*", "", true, false):
		if not (node is Device or node is Powered) or corner.is_ancestor_of(node):
			continue
		var at := _hub_position(node.get_parent(), hub)
		for point in corner_points:
			nearest = minf(nearest, at.distance_to(point))
	hub.free()

	# Measured 12.51 m (the security wing).
	assert_float(nearest).is_greater(float(JAMMING.get("radius")) + 2.0)


# `node`'s position in `root`'s space, out of the tree (the chain of Node3D transforms).
func _hub_position(node: Node, root: Node) -> Vector3:
	var xform := Transform3D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform.origin
