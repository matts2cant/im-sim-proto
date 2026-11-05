extends GdUnitTestSuite

const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const DOORWAY_LABELS: Array[String] = [
	"1 Movement",
	"2 Perception",
	"3 Physics & Fire",
	"4 Shooting Range",
	"5 Security",
	"6 AI Arena",
	"7 Inventory & Abilities",
	"Mission",
]


func test_hub_has_player_spawn() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())

	assert_object(hub.get_node_or_null("PlayerSpawn")).is_instanceof(Marker3D)


func test_hub_has_labelled_doorways() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())

	var texts: Array[String] = []
	for label: Label3D in hub.get_node("Doorways").find_children("*", "Label3D"):
		texts.append(label.text)
	assert_array(texts).contains_exactly_in_any_order(DOORWAY_LABELS)


func test_player_spawns_at_player_spawn() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())

	var player := hub.get_node_or_null("Player") as Player
	assert_object(player).is_not_null()
	assert_vector(player.position).is_equal((hub.get_node("PlayerSpawn") as Marker3D).position)


func test_player_camera_is_the_only_camera() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())

	var cameras := hub.find_children("*", "Camera3D", true, false)
	assert_int(cameras.size()).is_equal(1)
	assert_object(cameras[0].get_parent().get_parent()).is_same(hub.get_node("Player"))


func test_movement_course_sits_behind_movement_doorway() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())

	var course := hub.get_node_or_null("MovementCourse") as Node3D
	var doorway := hub.get_node("Room/DoorwayMovement") as Node3D
	assert_object(course).is_not_null()
	assert_float(course.position.x).is_equal(doorway.position.x)
	assert_float(course.position.y).is_equal(0.0)
