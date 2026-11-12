extends GdUnitTestSuite
## IconMesh (ADR 0130): a kind's line icon (the strokes DeviceIcon draws) as a flat 3D mesh facing
## +Z, `side` metres square around the origin; every kind's icon builds.


func test_a_rect_is_four_lines_inside_its_square() -> void:
	var lines := IconMesh.segments(PackedStringArray(["rect 0 0 24 24"]), 0.024)

	assert_int(lines.size()).is_equal(8)
	assert_vector(lines[0]).is_equal_approx(Vector2(-0.012, 0.012), Vector2.ONE * 1e-6)
	assert_vector(lines[1]).is_equal_approx(Vector2(0.012, 0.012), Vector2.ONE * 1e-6)


func test_y_runs_up_and_dashes_leave_gaps() -> void:
	var line := IconMesh.segments(PackedStringArray(["12,4 12,20"]), 0.024)
	var dashes := IconMesh.segments(PackedStringArray(["dash 4,8 20,8"]), 0.024)

	assert_float(line[0].y).is_greater(line[1].y)
	# 16 units of 2-unit dashes with 2-unit gaps: 4 dashes.
	assert_int(dashes.size()).is_equal(8)


func test_the_mesh_faces_the_front_and_stays_in_its_square() -> void:
	var side := 0.02
	var mesh := IconMesh.build(PackedStringArray(["circle 12 12 6", "4,4 20,20"]), side)

	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_int(vertices.size()).is_greater(0)
	var stroke := side * IconMesh.STROKE / IconMesh.GRID
	for vertex in vertices:
		assert_float(absf(vertex.x)).is_less_equal(side * 0.5 + stroke)
		assert_float(absf(vertex.y)).is_less_equal(side * 0.5 + stroke)
		assert_float(vertex.z).is_equal(0.0)
	# Wound clockwise seen from +Z (Godot's front faces).
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var a := vertices[indices[0]]
	var normal := (vertices[indices[2]] - a).cross(vertices[indices[1]] - a)
	assert_float(normal.z).is_greater(0.0)


func test_every_kind_icon_builds() -> void:
	for kind in DeviceKinds.shipped().kinds:
		var mesh := IconMesh.build(kind.icon, 0.02)
		assert_int(mesh.get_surface_count()).override_failure_message(kind.name).is_equal(1)
