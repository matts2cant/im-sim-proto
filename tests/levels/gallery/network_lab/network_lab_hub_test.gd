extends GdUnitTestSuite
## Network lab inside the hub (behind doorway "8 Network Lab" on the west wall, hub z -2, between the
## mission doorway (z -7.5) and room 7's (z 7.5)): its rooms keep 0.5 m of void to every other
## gallery room (room 7's hall north of it from hub z 1, the movement course's hall from z -19), the
## room sits on its doorway turned west, the player walks in from the hub and the navmesh reaches
## the stations (design/levels/hub-and-gallery.md "8 Network lab").

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const LAB := "NetworkLab"
## Clearance kept to the other rooms' outer faces (m, surface to surface).
const VOID := 0.5
## Lab-local floor points: corridor, hall centre, each station's stand spot, inside the closet.
const NAV_POINTS: Array[Vector3] = [
	Vector3(0, 0, -2),
	Vector3(5, 0, -11),
	Vector3(-0.9, 0, -6),
	Vector3(-0.6, 0, -12),
	Vector3(2.6, 0, -16.4),
	Vector3(10.6, 0, -15.6),
	Vector3(2.6, 0, -5.6),
]


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_lab_keeps_clear_of_every_other_gallery_room() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())
	var lab := hub.get_node(LAB)
	var ours: Dictionary[String, Rect2] = {}
	var theirs: Dictionary[String, Rect2] = {}
	for node in hub.find_children("*", "", true, false):
		var room := node as Room
		if room == null or room == hub.get_node("Room"):
			continue
		var rect := _outer_rect(hub, room)
		if lab.is_ancestor_of(room):
			ours[String(hub.get_path_to(room))] = rect
		else:
			theirs[String(hub.get_path_to(room))] = rect
	assert_int(ours.size()).is_equal(3)
	for a: String in ours:
		# West of the hub's west wall: the corridor's hub-side wall is that wall (x -15.5 to -15).
		assert_float(ours[a].end.x).override_failure_message(a).is_less_equal(-15.0)
		for b: String in theirs:
			var grown := theirs[b].grow(VOID - 0.001)
			(
				assert_bool(ours[a].intersects(grown))
				. override_failure_message("%s within %.1f m of %s" % [a, VOID, b])
				. is_false()
			)


func test_the_room_sits_on_doorway_eight_the_player_walks_in_and_the_navmesh_reaches_it() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	var scene := driver.runner.scene()
	var lab := scene.get_node(LAB) as Node3D
	var doorway := scene.get_node("Room/DoorwayNetworkLab") as Node3D
	var hub_room := scene.get_node("Room") as Room
	var nav := scene.get_node("Navigation") as LevelNavigation
	await driver.settle()
	# Origin on the outer face of the hub's west wall, centred on the doorway; -Z points west.
	assert_float(lab.global_position.x).is_equal_approx(-(hub_room.size.x * 0.5 + hub_room.wall_thickness), 0.0001)
	assert_float(lab.global_position.z).is_equal_approx(doorway.global_position.z, 0.0001)
	assert_vector(-lab.global_basis.z).is_equal_approx(Vector3.LEFT, Vector3.ONE * 0.0001)
	assert_object(scene.get_node("Doorways/LabelNetworkLab")).is_not_null()
	var spawn := (scene.get_node("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), nav.get_navigation_map(), spawn)).is_true()
	for local: Vector3 in NAV_POINTS:
		var target := lab.to_global(local)
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(), spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)
	# From 3 m in front of the doorway, walking west: through the corridor into the hall.
	await driver.place(Vector3(-12, 0, -2), PI / 2.0)
	await driver.hold(&"move_forward", 150)
	var feet := lab.to_local(driver.player.global_position)
	assert_float(feet.z).is_less(-5.0)
	assert_float(absf(feet.x)).is_less(1.0)


## A kit Room's outer footprint in hub x / z (Rect2 position x = hub x, y = hub z).
func _outer_rect(hub: Node3D, room: Room) -> Rect2:
	var xform := room.transform
	var parent := room.get_parent()
	while parent != hub and parent != null:
		if parent is Node3D:
			xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	var half := Vector3(room.size.x * 0.5 + room.wall_thickness, 0, room.size.z * 0.5 + room.wall_thickness)
	var low := xform * -half
	var high := xform * half
	# Shared outer faces touch but must not overlap: shrink by a millimetre.
	return Rect2(Vector2(low.x, low.z), Vector2.ZERO).expand(Vector2(high.x, high.z)).grow(-0.001)
