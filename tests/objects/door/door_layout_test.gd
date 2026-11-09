extends GdUnitTestSuite
## Unit (ADR 0098): DoorLayout places a door's handle, keyhole and wall boxes from its settings and
## wall. A pocket door's handle reaches past the leaf's leading edge, so it stands out of the jamb
## when the leaf is in the wall; a gate outside its wall line keeps it on the leaf. Wall boxes sit on
## the wall faces on the side away from the pocket, clear of the leaf's sweep, stacked downward, or on
## a short corridor's side wall facing across it. All in door-local metres.

const PLAIN: DoorSettings = preload("res://objects/door/door_settings.tres")
const FENCE_GATE: DoorSettings = preload("res://objects/door/fence_gate_settings.tres")
const ROLLER: DoorSettings = preload("res://objects/door/roller_door_settings.tres")
const VEHICLE_GATE: DoorSettings = preload("res://objects/door/vehicle_gate_settings.tres")


func test_a_pocket_door_handle_stands_out_of_the_jamb_when_open() -> void:
	# Leaf 1.3 m wide (doorway 1.2 m), sliding 1.3 m to +X into a 0.25 m wall: in the wall.
	assert_bool(DoorLayout.in_wall(PLAIN, 0.25)).is_true()
	var centre := DoorLayout.closed_centre(PLAIN)
	var handle := DoorLayout.handle_box(PLAIN, 0.25)
	# Closed: from 0.12 m past the leading edge (-0.65) to 0.2 m onto the leaf.
	assert_float(centre.x + handle.position.x).is_equal_approx(-0.77, 0.001)
	assert_float(centre.x + handle.end.x).is_equal_approx(-0.45, 0.001)
	assert_float(centre.y + handle.get_center().y).is_equal_approx(DoorLayout.HANDLE_HEIGHT, 0.001)
	# Proud of both faces (the leaf is 0.06 m thick), inside the wall (0.125 m each side).
	assert_float(handle.end.z).is_equal_approx(0.055, 0.001)
	assert_float(handle.end.z).is_less(0.125)
	# Open (+1.3 m): its inner end is 0.07 m into the 1.2 m doorway (the jamb is at x 0.6).
	assert_float(centre.x + handle.position.x + PLAIN.travel.x).is_equal_approx(0.53, 0.001)


func test_a_gate_outside_its_wall_line_keeps_its_handle_on_the_leaf() -> void:
	# The fence gate slides 0.3 m in front of its 0.3 m posts: its leaf is always in view.
	assert_bool(DoorLayout.in_wall(FENCE_GATE, 0.3)).is_false()
	var handle := DoorLayout.handle_box(FENCE_GATE, 0.3)
	assert_float(handle.position.x).is_equal_approx(-0.65, 0.001)
	assert_float(handle.end.x).is_equal_approx(-0.45, 0.001)


func test_a_rising_leaf_has_a_bar_near_its_bottom() -> void:
	assert_bool(DoorLayout.slides_sideways(ROLLER)).is_false()
	var centre := DoorLayout.closed_centre(ROLLER)
	var handle := DoorLayout.handle_box(ROLLER, 0.5)
	assert_float(centre.y + handle.get_center().y).is_equal_approx(DoorLayout.BAR_HEIGHT, 0.001)
	assert_float(handle.get_center().x).is_equal_approx(0.0, 0.001)


func test_the_keyhole_is_on_the_handle_face_on_both_sides() -> void:
	var centre := DoorLayout.closed_centre(PLAIN)
	var handle := DoorLayout.handle_box(PLAIN, 0.25)
	for front: bool in [true, false]:
		var place := DoorLayout.keyhole(PLAIN, front)
		var at := place.origin
		# On the handle's face, inside its outline, facing out of that face.
		assert_float(absf(at.z)).is_equal_approx(handle.end.z, 0.001)
		assert_bool(at.x > handle.position.x and at.x < handle.end.x).is_true()
		assert_bool(at.y > handle.position.y and at.y < handle.end.y).is_true()
		assert_float(place.basis.z.z).is_equal_approx(1.0 if front else -1.0, 0.001)
		# Visible on the closed leaf: inside the doorway, not in the jamb.
		assert_float(centre.x + at.x).is_greater(-0.6)


func test_wall_boxes_sit_on_the_wall_faces_away_from_the_pocket() -> void:
	for front: bool in [true, false]:
		var place := DoorLayout.box_transform(PLAIN, 0.25, 0.0, front, 1.35)
		assert_float(place.origin.x).is_equal_approx(-0.6 - DoorLayout.BOX_COLUMN, 0.001)
		assert_float(place.origin.z).is_equal_approx(0.125 if front else -0.125, 0.001)
		assert_float(place.basis.z.z).is_equal_approx(1.0 if front else -1.0, 0.001)
	# A leaf sliding to -X: the boxes go to +X.
	var mirrored := PLAIN.duplicate() as DoorSettings
	mirrored.travel = Vector3(-1.3, 0, 0)
	assert_float(DoorLayout.box_transform(mirrored, 0.25, 0.0, true, 1.35).origin.x).is_equal_approx(0.77, 0.001)


func test_wall_boxes_clear_the_leaf_sweep_for_every_preset() -> void:
	# Wall thicknesses as the levels use them: 0.25 m pocket doors, 0.3 m fence-gate posts, 0.5 m
	# for the roller doors, 0.4 m vehicle-gate posts.
	var presets: Dictionary[DoorSettings, float] = {PLAIN: 0.25, FENCE_GATE: 0.3, ROLLER: 0.5, VEHICLE_GATE: 0.4}
	for settings: DoorSettings in presets:
		var wall := presets[settings]
		var sweep := DoorLayout.sweep(settings, wall)
		for front: bool in [true, false]:
			var place := DoorLayout.box_transform(settings, wall, 0.0, front, 1.35)
			# The largest box (0.12 x 0.17 x 0.04 m) around that origin.
			var box := place * AABB(Vector3(-0.06, -0.085, 0.0), Vector3(0.12, 0.17, 0.04))
			var where := "%s %s" % [settings.resource_path.get_file(), "front" if front else "back"]
			assert_bool(box.intersects(sweep)).override_failure_message(where).is_false()


func test_stacked_boxes_go_down_from_the_top_with_a_gap() -> void:
	var ys := DoorLayout.box_heights([0.17, 0.13] as Array[float])
	assert_float(ys[0]).is_equal_approx(DoorLayout.BOX_TOP, 0.001)
	# Surface to surface: 1.35 - 0.085 - 0.06 - 0.065 = 1.14.
	assert_float(ys[1]).is_equal_approx(1.14, 0.001)


func test_a_box_in_a_short_corridor_faces_across_it() -> void:
	var place := DoorLayout.box_transform(PLAIN, 0.25, 0.75, false, 1.35)
	assert_float(place.origin.x).is_equal_approx(-0.75, 0.001)
	assert_float(place.origin.z).is_equal_approx(-(0.125 + DoorLayout.SIDE_DEPTH), 0.001)
	assert_bool(place.basis.z.is_equal_approx(Vector3.RIGHT)).is_true()
