extends GdUnitTestSuite
## Integration: SupportWake wakes the sleeping bodies touching a body, and the ones touching those,
## but nothing out of reach (ADR 0055). Small crates are 0.6 m cubes on a flat floor at y = 0.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	await Objects.frames(get_tree(), 5)


func test_wakes_the_whole_column_above_but_not_a_crate_out_of_reach() -> void:
	var watch := CrateWatch.new()
	watch.column(_floor, 0.0, 0.0, 3)
	# 0.4 m gap (surface to surface) from the column: well beyond the 0.05 m margin.
	var apart := watch.small(_floor, 1.0, 0.3, 0.0)
	await watch.frames(get_tree(), 120)
	for crate in watch.crates:
		assert_bool(crate.sleeping).is_true()

	var woken := SupportWake.wake_touching(watch.crates[0])

	assert_int(woken).is_equal(2)
	assert_bool(watch.crates[1].sleeping).is_false()
	assert_bool(watch.crates[2].sleeping).is_false()
	assert_bool(watch.crates[0].sleeping).is_true()
	assert_bool(apart.sleeping).is_true()


func test_bounds_cover_the_shapes_and_grow_by_the_margin() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0)) as RigidBody3D
	var bounds := SupportWake.shapes_bounds(crate)
	assert_vector(bounds.size).is_equal_approx(Vector3.ONE * 0.6, Vector3.ONE * 0.001)

	var query := SupportWake.grown_query(crate, [])
	var box := query.shape as BoxShape3D
	assert_vector(box.size).is_equal_approx(Vector3.ONE * 0.7, Vector3.ONE * 0.001)
	assert_vector(query.transform.origin).is_equal_approx(Vector3(0, 0.3, 0), Vector3.ONE * 0.001)
	assert_int(query.collision_mask).is_equal(PhysicsLayers.OBJECTS)


func test_does_nothing_for_a_body_outside_the_tree() -> void:
	var crate := auto_free((load(Objects.SMALL_CRATE) as PackedScene).instantiate()) as RigidBody3D
	assert_int(SupportWake.wake_touching(crate)).is_equal(0)
	assert_int(SupportWake.wake_touching(null)).is_equal(0)
