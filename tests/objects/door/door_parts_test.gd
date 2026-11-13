extends GdUnitTestSuite
## Door's parts are exported NodePaths the scene sets (S20 of the 2026-11-13 audit): door.tscn sets
## every one, and a Door on a bare StaticBody3D without parts still works (opens, saves) without
## errors.

const DOOR_SCENE: PackedScene = preload("res://objects/door/door.tscn")
const SETTINGS: DoorSettings = preload("res://objects/door/door_settings.tres")


func test_the_door_scene_sets_every_part() -> void:
	var entity: Node3D = auto_free(DOOR_SCENE.instantiate())
	var door := Door.of(entity)
	for path: NodePath in [
		door.panel_path,
		door.panel_mesh_path,
		door.attenuator_path,
		door.doorway_path,
		door.carve_path,
		door.link_path,
		door.free_link_path,
	]:
		assert_object(door.get_node_or_null(path)).override_failure_message(str(path)).is_not_null()
	var hardware := DoorHardware.of(entity)
	assert_object(hardware.get_node_or_null(hardware.handle_path)).is_not_null()
	assert_object(hardware.get_node_or_null(hardware.handle_mesh_path)).is_not_null()


func test_a_door_without_parts_opens_and_saves() -> void:
	var root: Node3D = auto_free(Node3D.new())
	root.position = Vector3(-240, 0, -280)
	add_child(root)
	var entity := StaticBody3D.new()
	entity.name = "Bare"
	var door := Door.new()
	door.settings = SETTINGS
	entity.add_child(door)
	root.add_child(entity)

	assert_bool(door.use(root)).is_true()
	assert_bool(door.is_open()).is_true()
	for i in ceili(SETTINGS.open_time * 2.0 * Engine.physics_ticks_per_second):
		if not door.is_moving():
			break
		await get_tree().physics_frame
	assert_float(door.openness).is_equal_approx(1.0, 0.001)
	assert_bool(door.save_state()["open"]).is_true()
