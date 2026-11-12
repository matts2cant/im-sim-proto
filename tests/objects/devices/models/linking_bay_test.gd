extends GdUnitTestSuite
## LinkingBay (ADR 0130): a 0.6 x 1.9 m rack whose rack units snap to 1U slots on its rails, with a
## blank panel in every free slot and, in the glass variant, a closed door with a lock.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const BAY := preload("res://objects/devices/models/linking_bay.tscn")
const SWITCH := preload("res://objects/devices/models/switch_rack.tscn")
const ROUTER := preload("res://objects/devices/models/router_rack.tscn")


func test_slots_are_one_unit_apart_from_the_top() -> void:
	assert_float(LinkingBay.slot_y(0, 1)).is_equal_approx(LinkingBay.TOP_Y - LinkingBay.UNIT, 1e-6)
	assert_float(LinkingBay.slot_y(5, 2) - LinkingBay.slot_y(6, 2)).is_equal_approx(LinkingBay.UNIT, 1e-6)
	assert_int(LinkingBay.slot_for(LinkingBay.slot_y(9, 2), 2)).is_equal(9)
	# Every slot fits between the plinth and the top cap.
	assert_float(LinkingBay.slot_y(LinkingBay.SLOTS - 1, 1)).is_greater_equal(LinkingBay.CAP)


func test_units_snap_to_the_nearest_slot_on_the_rails() -> void:
	var bay := _bay(false)
	var router := ROUTER.instantiate() as DeviceModel
	# A third of a unit too high and off to the side: snaps back to slot 4.
	router.position = Vector3(0.03, LinkingBay.slot_y(4, 2) + LinkingBay.UNIT * 0.3, 0.1)
	bay.add_child(router)

	bay.rebuild()

	assert_vector(router.position).is_equal_approx(
		Vector3(0.0, LinkingBay.slot_y(4, 2), LinkingBay.RAIL_Z), Vector3.ONE * 1e-5
	)


func test_free_slots_get_blank_panels() -> void:
	var bay := _bay(false)
	var switch := SWITCH.instantiate() as DeviceModel
	switch.position.y = LinkingBay.slot_y(10, 1)
	var router := ROUTER.instantiate() as DeviceModel
	router.position.y = LinkingBay.slot_y(12, 2)
	bay.add_child(switch)
	bay.add_child(router)

	bay.rebuild()

	var taken := bay.occupied()
	assert_bool(taken[10] and taken[12] and taken[13]).is_true()
	assert_bool(taken[11]).is_false()
	assert_int(bay.blanks.size()).is_equal(LinkingBay.SLOTS - 3)
	for blank in bay.blanks:
		var unit_box := AABB(Vector3(-0.3, router.position.y, 0.0), Vector3(0.6, 2.0 * LinkingBay.UNIT, 1.0))
		assert_bool(blank.intersects(unit_box)).is_false()


func test_the_glass_variant_has_a_closed_door_with_a_lock() -> void:
	var open := _bay(false)
	var glass := _bay(true)

	assert_object(open.door).is_null()
	assert_object(glass.door).is_not_null()
	assert_object(glass.door.get_node_or_null("Glass")).is_not_null()
	assert_object(glass.door.get_node_or_null("Lock")).is_not_null()
	# Closed: the door covers the front of the bay, in front of the rails.
	var frame := glass.door.get_node("Frame") as MeshInstance3D
	var box := frame.get_aabb()
	assert_float(box.size.x).is_equal_approx(LinkingBay.WIDTH - LinkingBay.SIDE * 2.0, 0.001)
	assert_float(box.position.z).is_greater(LinkingBay.RAIL_Z)


func test_the_bay_is_solid_and_its_parts_never_z_fight() -> void:
	var bay := _bay(true)
	var switch := SWITCH.instantiate() as DeviceModel
	switch.position.y = LinkingBay.slot_y(6, 1)
	bay.add_child(switch)
	bay.rebuild()

	var body := bay.get_node("Body") as StaticBody3D
	assert_int(body.collision_layer).is_equal(PhysicsLayers.WORLD)
	var overlaps := KitGeometry.coplanar_mesh_overlaps(bay)
	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


func _bay(glass: bool) -> LinkingBay:
	var bay := BAY.instantiate() as LinkingBay
	bay.glass_door = glass
	add_child(bay)
	auto_free(bay)
	return bay
