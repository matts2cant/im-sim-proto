extends GdUnitTestSuite
## Hub geometry (with the movement course behind doorway "1 Movement"): no two kit parts
## render different materials on the same plane. Guards against the corridor ceiling that
## ended flush with the hub and hall wall faces and z-fought above both corridor doorways.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")


func test_no_coplanar_faces_with_different_materials() -> void:
	var hub: Node3D = HUB_SCENE.instantiate()
	hub.get_node("Player").free()
	add_child(hub)
	auto_free(hub)
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(hub)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()
