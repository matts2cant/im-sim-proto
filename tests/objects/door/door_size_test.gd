extends GdUnitTestSuite
## Integration (ADR 0090): door size is data. The same `door.tscn` with other DoorSettings fills a
## bigger doorway: its panel, noise attenuator, navigation carve and wall boxes (ADR 0098) follow the
## settings' doorway, and it opens by the settings' travel (a roller door rises, a gate slides past
## its posts on one side of the fence). Doors with different settings never share their shapes.

const Wait := preload("res://tests/helpers/wait.gd")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const ROLLER: DoorSettings = preload("res://objects/door/roller_door_settings.tres")
const GATE: DoorSettings = preload("res://objects/door/vehicle_gate_settings.tres")
const PLAIN: DoorSettings = preload("res://objects/door/door_settings.tres")
## Far from the origin and from other suites' fixtures (no navigation here).
const ORIGIN := Vector3(-260, 0, -140)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	_root.position = ORIGIN
	add_child(_root)


func test_a_roller_door_fills_4_by_4_m_and_rises_into_the_wall_above() -> void:
	var entity := _door(ROLLER, Vector3.ZERO)
	var door := Door.of(entity)
	var panel := entity.get_node("Panel") as CollisionShape3D
	var size := (panel.shape as BoxShape3D).size
	assert_bool(size.is_equal_approx(Vector3(4.1, 4.05, 0.08))).is_true()
	var closed := panel.position
	assert_float(closed.y).is_equal_approx(2.03, 0.001)
	var carve := entity.get_node("NavCarve") as NavigationObstacle3D
	assert_float(carve.vertices[1].x).is_equal_approx(2.1, 0.001)
	assert_float(carve.height).is_equal_approx(4.0, 0.001)
	var doorway := entity.get_node("SoundAttenuator/Doorway") as CollisionShape3D
	assert_bool((doorway.shape as BoxShape3D).size.is_equal_approx(Vector3(4, 4, 0.6))).is_true()
	# Its leaf rises out of reach: a plain control box on each wall face beside the frame (ADR 0098).
	for front: bool in [true, false]:
		var boxes := door.hardware.controls(front)
		assert_int(boxes.size()).is_equal(1)
		assert_float(_in_door(door, boxes[0]).origin.x).is_equal_approx(-2.0 - DoorLayout.BOX_COLUMN, 0.001)
		assert_object((Usable.of(boxes[0]) as DoorControl).lock).is_null()

	# Closed, it blocks sight 3.5 m up (above any 1.2 x 2.2 m door); open, the doorway is clear.
	var space := entity.get_world_3d().direct_space_state
	var from := ORIGIN + Vector3(1.5, 3.5, 2)
	var to := ORIGIN + Vector3(1.5, 3.5, -2)
	assert_bool(PhysicsLayers.segment_clear(space, from, to)).is_false()
	assert_bool(door.open()).is_true()
	# 2.5 s to open: 150 physics frames, and margin.
	await Wait.frames(get_tree(), 165)
	assert_float(door.openness).is_equal(1.0)
	assert_float(panel.position.y - closed.y).is_equal_approx(4.1, 0.001)
	assert_float(panel.position.x).is_equal_approx(0.0, 0.001)
	assert_bool(PhysicsLayers.segment_clear(space, from, to)).is_true()
	# Loud: the panel starting to move is a noise of the settings' loudness.
	assert_float(ROLLER.slide_noise).is_greater_equal(10.0)


func test_a_gate_slides_along_one_side_of_its_fence() -> void:
	var entity := _door(GATE, Vector3.ZERO)
	var door := Door.of(entity)
	var panel := entity.get_node("Panel") as CollisionShape3D
	assert_bool(door.panel_size.is_equal_approx(Vector3(6.1, 3.05, 0.08))).is_true()
	assert_float(panel.position.z).is_equal_approx(-0.3, 0.001)

	door.open()
	await Wait.frames(get_tree(), 195)

	assert_float(panel.position.x).is_equal_approx(6.2, 0.001)
	assert_float(panel.position.z).is_equal_approx(-0.3, 0.001)
	# The doorway check for a body uses the doorway itself, not the panel's open place.
	assert_bool(door.close()).is_true()


func test_a_barred_gate_stops_bodies_but_not_sight_or_noise() -> void:
	# The vehicle gate is a grille (bars 0.22 m apart, 0.05 m wide, like the palisade fence).
	assert_float(GATE.bar_spacing).is_greater(0.0)
	var entity := _door(GATE, Vector3.ZERO)
	await Wait.frames(get_tree(), 2)
	var space := entity.get_world_3d().direct_space_state
	var bar := GATE.bar_width
	var count := floori((6.1 - bar) / GATE.bar_spacing) + 1
	var step := (6.1 - bar) / (count - 1)
	# Between two bars (half a step from the first one), at eye height: a clear line through the
	# gate. Along a bar: blocked. The rails (0.1 and 0.9 of its height) block a level line too.
	var between := -3.05 + bar * 0.5 + step * 0.5
	var first_bar := -3.05 + bar * 0.5
	assert_bool(_clear(space, Vector3(between, 1.65, 3), Vector3(between, 1.65, -3))).is_true()
	assert_bool(_clear(space, Vector3(first_bar, 1.65, 3), Vector3(first_bar, 1.65, -3))).is_false()
	assert_bool(_clear(space, Vector3(between, 0.31, 3), Vector3(between, 0.31, -3))).is_false()
	# A standing body (player capsule) in the gate opening touches the bars.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, ORIGIN + Vector3(0.0, 0.95, -0.3))
	query.collision_mask = PhysicsLayers.WORLD
	assert_array(space.intersect_shape(query, 1)).is_not_empty()
	# A grille does not muffle noise.
	var attenuator := entity.get_node("SoundAttenuator") as SoundAttenuator
	assert_bool(attenuator.enabled).is_false()


func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return PhysicsLayers.segment_clear(space, ORIGIN + from, ORIGIN + to)


func test_doors_with_other_settings_do_not_share_shapes() -> void:
	var small := _door(PLAIN, Vector3(10, 0, 0))
	var big := _door(ROLLER, Vector3(-10, 0, 0))
	var small_shape := (small.get_node("Panel") as CollisionShape3D).shape as BoxShape3D
	var big_shape := (big.get_node("Panel") as CollisionShape3D).shape as BoxShape3D

	assert_object(small_shape).is_not_same(big_shape)
	assert_bool(small_shape.size.is_equal_approx(Vector3(1.3, 2.25, 0.06))).is_true()
	var small_carve := small.get_node("NavCarve") as NavigationObstacle3D
	assert_float(small_carve.vertices[1].x).is_equal_approx(0.7, 0.001)


func test_wall_boxes_in_a_narrow_corridor_hang_on_its_side_wall() -> void:
	# A 1.2 m keypad door at the end of a 1.5 m corridor on its front: the side wall is 0.75 m from the
	# doorway's centre line, where a box beside the doorway (0.77 m) would sit inside the wall.
	var entity := DOOR.instantiate() as StaticBody3D
	var door := entity.get_node("Door") as Door
	door.settings = PLAIN
	door.front_side_wall = 0.75
	var keypad := KeypadLock.new()
	keypad.name = "KeypadLock"
	entity.add_child(keypad)
	_root.add_child(entity)
	var face := door.wall_thickness * 0.5
	var front := _in_door(door, door.hardware.controls(true)[0])
	# Its back face against the side wall, its face across the corridor (+X), in from the door's wall.
	assert_float(front.origin.x).is_equal_approx(-0.75, 0.001)
	assert_float(front.origin.z).is_equal_approx(face + DoorLayout.SIDE_DEPTH, 0.001)
	assert_bool(front.basis.z.is_equal_approx(Vector3.RIGHT)).is_true()
	# The back face (no corridor) keeps its box beside the doorway, facing back.
	var back := _in_door(door, door.hardware.controls(false)[0])
	assert_float(back.origin.x).is_equal_approx(-0.6 - DoorLayout.BOX_COLUMN, 0.001)
	assert_float(back.origin.z).is_equal_approx(-face, 0.001)
	assert_bool(back.basis.z.is_equal_approx(Vector3.FORWARD)).is_true()


func _door(settings: DoorSettings, at: Vector3) -> StaticBody3D:
	var entity := DOOR.instantiate() as StaticBody3D
	(entity.get_node("Door") as Door).settings = settings
	entity.position = at
	_root.add_child(entity)
	return entity


# A wall box's transform in its door's frame (the boxes hang under the door's controller).
static func _in_door(door: Door, box: Node3D) -> Transform3D:
	return door.entity.global_transform.affine_inverse() * box.global_transform
