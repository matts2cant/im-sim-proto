extends GdUnitTestSuite
## DeckArView.mount_bodies() (ADR 0130 step 3): a cable's ceiling run from a rack unit in a linking bay
## rises past the bay's cabinet to the room's ceiling, not to the bay's top cap.

const BAY := preload("res://objects/devices/models/linking_bay.tscn")
const SWITCH := preload("res://objects/network/switch_rack.tscn")
const ORIGIN := Vector3(-300, 0, 260)
const CEILING_Y := 4.0


func test_a_rack_units_ceiling_ray_ignores_its_bay() -> void:
	var root := Node3D.new()
	add_child(root)
	auto_free(root)
	root.global_position = ORIGIN
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	shape.shape = box
	ceiling.add_child(shape)
	root.add_child(ceiling)
	ceiling.position = Vector3(0, CEILING_Y + 0.1, 0)
	var bay := BAY.instantiate() as LinkingBay
	var unit := SWITCH.instantiate() as Node3D
	unit.position.y = LinkingBay.slot_y(6, 1)
	bay.add_child(unit)
	root.add_child(bay)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var excluded := DeckArView.mount_bodies(unit)
	var cabinet := (bay.get_node("Body") as StaticBody3D).get_rid()
	assert_bool(excluded.has(cabinet)).is_true()
	assert_bool(excluded.has((unit as CollisionObject3D).get_rid())).is_true()
	assert_bool(excluded.has(ceiling.get_rid())).is_false()

	var from := unit.global_position
	var space := root.get_world_3d().direct_space_state
	var plain := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 8.0, PhysicsLayers.WORLD)
	plain.exclude = [(unit as CollisionObject3D).get_rid()]
	# Without the bay excluded the ray stops under the bay's top cap (1.8 m), with it at the ceiling.
	assert_float((space.intersect_ray(plain)["position"] as Vector3).y).is_less(ORIGIN.y + LinkingBay.HEIGHT + 0.01)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 8.0, PhysicsLayers.WORLD)
	query.exclude = excluded
	assert_float((space.intersect_ray(query)["position"] as Vector3).y).is_equal_approx(CEILING_Y, 0.01)
