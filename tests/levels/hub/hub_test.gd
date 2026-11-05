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
	for label: Label3D in hub.find_children("*", "Label3D"):
		texts.append(label.text)
	assert_array(texts).contains_exactly_in_any_order(DOORWAY_LABELS)
