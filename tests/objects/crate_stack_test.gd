extends GdUnitTestSuite
## Integration: stacks of small crates on a flat floor stand still on their own (ADR 0054).

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	# CSG collision is built a few frames after load.
	await Wait.frames(get_tree(), 5)


func test_column_and_pyramid_rest_still_for_five_seconds() -> void:
	var watch := CrateWatch.new()
	# Column of 3 (top at 1.8 m) and a pyramid: 2 side by side, 0.02 m gap (surface to surface),
	# centres 0.62 m apart, one on top centred over the gap.
	assert_float(watch.column(_floor, -2.0, 0.0, 3)).is_equal_approx(1.8, 0.001)
	watch.small(_floor, 2.0, 0.3, 0.0)
	watch.small(_floor, 2.62, 0.3, 0.0)
	watch.small(_floor, 2.31, 0.9, 0.0)

	await watch.frames(get_tree(), 300)

	print(watch.summary("rest"))
	assert_float(watch.max_drift()).is_less(0.02)
	assert_float(watch.max_tilt()).is_less(2.0)
	assert_float(watch.max_end_speed()).is_less(0.05)
	assert_array(EventLog.find(&"object.broken")).is_empty()


func test_props_do_not_scan_the_player_layer() -> void:
	# ADR 0054: the player's kinematic body would push props with infinite mass.
	var paths: Array[String] = [
		Objects.SMALL_CRATE,
		Objects.LARGE_CRATE,
		Objects.METAL_CRATE,
		Objects.CARDBOARD_BOX,
		Objects.EXPLOSIVE_BARREL,
		Objects.GLASS_BOTTLE,
		"res://items/weapons/pistol/pistol_pickup.tscn",
		"res://items/medkit/medkit.tscn",
	]
	for i in paths.size():
		var prop := Objects.spawn(_floor, paths[i], Vector3(i * 2.0, 1.0, 3.0)) as RigidBody3D
		assert_int(prop.collision_mask & PhysicsLayers.PLAYER).override_failure_message(paths[i]).is_equal(0)
		assert_int(prop.collision_mask).is_equal(PhysicsLayers.OBJECT_MASK)
