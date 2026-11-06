extends GdUnitTestSuite
## Kit showcase: no two kit parts render different materials on the same plane (the vents and the
## room used to sit flush on the ground slab: metal vent floors and the room's door threshold
## z-fought with the concrete ground).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SHOWCASE_SCENE: PackedScene = preload("res://levels/kit/kit_showcase.tscn")


func test_no_coplanar_faces_with_different_materials() -> void:
	var showcase: Node3D = SHOWCASE_SCENE.instantiate()
	add_child(showcase)
	auto_free(showcase)
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(showcase)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()
