extends GdUnitTestSuite
## Shooting range M13a tools (ADR 0125) on the room scene alone, loaded once: the walking dummy 15 m
## out (centre to centre from the firing line at sampled points of its walk) inside its lane, the
## spray wall 10 m out, the stats board's targets and height, the controls on the counter top, the
## second rack; in the tree a bullet ray at the spray wall leaves a mark the board counts, and the
## reset button stands downed dummies up. Room-local coordinates.

const ROOM_SCENE: PackedScene = preload("res://levels/gallery/shooting_range/shooting_range_room.tscn")
const MARKED: Receptron = preload("res://objects/components/receptrons/marked_by_bullets.tres")
const ORIGIN := Vector3(-380, 0, 300)
## The firing line (the counter's lip).
const FIRING_LINE_Z := -8.0
## Half the dummy's span across the arms (1.07 m).
const ARM_HALF := 0.535

var _room: Node3D


func before() -> void:
	_room = ROOM_SCENE.instantiate() as Node3D
	_room.position = ORIGIN
	add_child(_room)
	for i in 5:
		await get_tree().physics_frame


func after() -> void:
	_room.free()


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func test_walking_dummy_walks_4_m_across_its_lane_15_m_out() -> void:
	var walker := _room.get_node("Lanes/DummyWalking") as TrainingDummy
	var shuttle := walker.get_node("Shuttle") as Shuttle
	var hall := _room.get_node("Shell/Hall") as Room
	var east_wall := hall.position.x + hall.size.x * 0.5
	var divider := _room.get_node("Lanes/Divider6") as Ledge

	assert_float(shuttle.travel).is_equal_approx(4.0, 0.0001)
	# Walking speed: a guard's walk (1.5 m/s), slower than the player's (4 m/s).
	assert_float(shuttle.speed).is_between(1.2, 2.0)
	assert_vector(shuttle.axis).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	assert_vector(-walker.basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)
	# Sampled along its walk: always 15 m from the line, arms inside the lane east of divider 6.
	for offset: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		var at := shuttle.centre() + shuttle.axis * offset
		assert_float(FIRING_LINE_Z - at.z).is_equal_approx(15.0, 0.0001)
		assert_float(at.x - ARM_HALF).is_greater(divider.position.x + 0.3)
		assert_float(east_wall - (at.x + ARM_HALF)).is_greater(0.3)


func test_spray_wall_stands_10_m_out_in_its_own_lane() -> void:
	var board := _room.get_node("SprayWall/Board") as Ledge
	var left := _room.get_node("Lanes/Divider5") as Ledge
	var right := _room.get_node("Lanes/Divider6") as Ledge

	# Its face (the lip) 10 m from the firing line, facing it.
	assert_float(FIRING_LINE_Z - board.position.z).is_equal_approx(10.0, 0.0001)
	assert_float(board.width).is_greater_equal(3.5)
	assert_float(board.height).is_greater_equal(3.0)
	assert_float(board.position.x - board.width * 0.5).is_greater(left.position.x)
	assert_float(board.position.x + board.width * 0.5).is_less(right.position.x)
	var marks := ImpactMarks.of(board)
	assert_object(marks).is_not_null()
	assert_int(marks.max_marks).is_equal(500)
	var receiver := board.get_node("StimulusReceiver") as StimulusReceiver
	assert_array(receiver.receptrons).contains([MARKED])


func test_stats_board_lists_every_target_above_the_line_of_fire() -> void:
	var board := _room.get_node("FiringLine/StatsBoard") as StatsBoard
	var expected: Array[String] = [
		"Lanes/Dummy5m", "Lanes/Dummy10m", "Lanes/DummyWalking", "Lanes/Dummy20m", "Lanes/Dummy40m", "SprayWall/Board"
	]

	for path: String in expected:
		assert_str(String(board.key_of(_room.get_node(path)))).override_failure_message(path).is_not_empty()
	# Its bottom edge (the 1.45 m backing) well above eye height (1.65 m) over the lanes.
	assert_float(board.position.y - 1.45 * 0.5).is_greater(2.5)
	assert_float(FIRING_LINE_Z - board.position.z).is_between(2.0, 6.0)


func test_controls_sit_on_the_counter_top_apart() -> void:
	var counter := _room.get_node("FiringLine/Counter") as Ledge
	var names: Array[String] = ["ResetStats", "ClearWall", "ResetDummies", "TuningTerminal", "TierSwitch"]
	var previous_right := -INF
	for name: String in names:
		var control := _room.get_node("FiringLine/" + name) as StaticBody3D
		var half := ((control.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size * 0.5
		assert_float(control.position.y).override_failure_message(name).is_equal_approx(counter.height, 0.0001)
		assert_float(control.position.z - half.z).is_greater(counter.position.z - counter.depth)
		assert_float(control.position.z + half.z).is_less(counter.position.z)
		# Left to right, at least 0.1 m apart.
		assert_float(control.position.x - half.x - previous_right).override_failure_message(name).is_greater(0.1)
		previous_right = control.position.x + half.x
		assert_object(Usable.of(control)).override_failure_message(name).is_not_null()


func test_second_rack_has_the_pistol_its_ammo_and_an_smg_slot() -> void:
	var table := _room.get_node("Rack2/Table") as Ledge
	var medkits := _room.get_node("Medkits/Table") as Ledge

	assert_str(String(ItemPickup.of(_room.get_node("Rack2/Pistol")).item.id)).is_equal("pistol")
	assert_int(ItemPickup.of(_room.get_node("Rack2/PistolAmmo")).count).is_equal(60)
	assert_str((_room.get_node("Rack2/SmgSlot") as Sign).text).contains("SMG")
	# East of the medkit table with a gap.
	var gap := (table.position.x - table.width * 0.5) - (medkits.position.x + medkits.width * 0.5)
	assert_float(gap).is_greater_equal(0.3)


func test_a_bullet_at_the_spray_wall_leaves_a_mark_the_board_counts() -> void:
	var marks := ImpactMarks.of(_room.get_node("SprayWall/Board"))
	var board := _room.get_node("FiringLine/StatsBoard") as StatsBoard
	marks.clear()
	board.reset()
	# From eye height at the firing line in lane 5, straight at the wall's aim mark.
	var from := _room.to_global(Vector3(12.5, 1.4, -7.6))

	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 25.0, from, _room.global_basis * Vector3.FORWARD, 60.0))
	await _frames(3)

	assert_int(marks.count()).is_equal(1)
	assert_vector(_room.to_local(marks.points()[0])).is_equal_approx(Vector3(12.5, 1.4, -18), Vector3.ONE * 0.001)
	assert_int(board.stats.hits(&"Board")).is_equal(1)


func test_reset_button_stands_downed_dummies_up() -> void:
	var dead := _room.get_node("Lanes/Dummy40m") as TrainingDummy
	var out := _room.get_node("Lanes/DummyWalking") as TrainingDummy
	dead.body.take_damage(&"damage.ballistic", 500.0, &"head")
	out.body.take_damage(&"damage.stun", 500.0)
	await _frames(2)
	assert_bool(dead.is_down and out.is_down).is_true()

	Usable.of(_room.get_node("FiringLine/ResetDummies")).use(null)
	await _frames(2)

	assert_bool(dead.is_down or out.is_down).is_false()
	assert_bool(dead.body.is_dead() or out.body.is_unconscious()).is_false()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
