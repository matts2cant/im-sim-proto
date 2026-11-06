extends GdUnitTestSuite
## Integration: bodies resting on a prop fall when it stops supporting them, even after they fell
## asleep (SupportWake, ADR 0055). Small crates are 0.6 m cubes on a flat floor at y = 0.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"
const MEDKIT := "res://items/medkit/medkit.tscn"
## Long enough for a settled stack to fall asleep (Jolt sleeps after ~0.5 s at rest).
const SLEEP_FRAMES := 120
## Three seconds to fall 0.6 m and come to rest.
const FALL_FRAMES := 180

var _floor: Node3D
var _watch: CrateWatch


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	_watch = CrateWatch.new()
	# CSG collision is built a few frames after load.
	await Objects.frames(get_tree(), 5)


func test_column_falls_when_the_bottom_crate_burns_out() -> void:
	_watch.column(_floor, 0.0, 0.0, 3)
	await _sleep_column()
	var flammable := Flammable.of(_watch.crates[0])
	flammable.ignite(null)
	# Burns out (and breaks) within half a second instead of 20 s.
	flammable.fuel_left = 0.3

	await _watch.frames(get_tree(), FALL_FRAMES)

	assert_array(Objects.logged(&"object.broken", "reason", &"burnt_out")).has_size(1)
	_assert_fell_one_level()


func test_column_falls_when_the_bottom_crate_is_broken() -> void:
	_watch.column(_floor, 0.0, 0.0, 3)
	await _sleep_column()

	# Health 30: one blunt hit of 40 breaks it.
	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 40.0, _watch.crates[0]))
	await _watch.frames(get_tree(), FALL_FRAMES)

	assert_array(Objects.logged(&"object.broken", "reason", &"destroyed")).has_size(1)
	_assert_fell_one_level()


func test_column_falls_when_the_bottom_crate_is_freed() -> void:
	# Any prop leaving the tree, e.g. a pickup consumed into the inventory.
	_watch.column(_floor, 0.0, 0.0, 3)
	await _sleep_column()

	_watch.crates[0].queue_free()
	await _watch.frames(get_tree(), FALL_FRAMES)

	_assert_fell_one_level()


func test_item_falls_when_the_item_under_it_is_consumed() -> void:
	# Two 0.09 m tall medkits stacked (equal mass: a 10 kg crate on a 0.6 kg medkit is not a stable
	# solver case). The top one's centre starts at 0.135 m and ends on the floor at 0.045 m.
	var lower := Objects.spawn(_floor, MEDKIT, Vector3(0, 0.045, 0)) as RigidBody3D
	var upper := Objects.spawn(_floor, MEDKIT, Vector3(0, 0.135, 0)) as RigidBody3D
	await _watch.frames(get_tree(), SLEEP_FRAMES)
	assert_bool(lower.sleeping).is_true()
	assert_bool(upper.sleeping).is_true()
	assert_float(upper.global_position.y).is_greater(0.11)

	ItemPickup.of(lower).consume()
	await _watch.frames(get_tree(), FALL_FRAMES)

	assert_float(upper.global_position.y).is_equal_approx(0.045, 0.02)


func test_crate_falls_when_the_barricade_under_it_burns_out() -> void:
	# A static (non-prop) Breakable: a crate balanced on the 2.2 m high, 0.12 m thick barricade.
	var barricade := Objects.spawn(_floor, Objects.WOODEN_BARRICADE, Vector3.ZERO)
	var crate := _watch.small(_floor, 0.0, 2.5, 0.0)
	await _sleep_column()
	var flammable := Flammable.of(barricade)
	flammable.ignite(null)
	flammable.fuel_left = 0.3

	await _watch.frames(get_tree(), FALL_FRAMES)

	assert_bool(is_instance_valid(barricade)).is_false()
	# It fell 2.2 m: it may have broken on landing; it is not left hanging.
	if is_instance_valid(crate):
		assert_float(crate.global_position.y).is_less(0.5)


func test_top_crate_falls_when_the_bottom_one_is_knocked_out() -> void:
	_watch.column(_floor, 0.0, 0.0, 2)
	await _sleep_column()

	# 10 kg crate knocked sideways at 8 m/s: it slides out from under the top one.
	_watch.crates[0].apply_central_impulse(Vector3(80.0, 0.0, 0.0))
	await _watch.frames(get_tree(), FALL_FRAMES)

	var top := _watch.crates[1]
	print("knocked out: bottom x %.3f top y %.3f" % [_watch.crates[0].global_position.x, top.global_position.y])
	assert_float(_watch.crates[0].global_position.x).is_greater(0.7)
	# On the floor, upright (0.3 m) or tipped on an edge (at most 0.43 m).
	assert_float(top.global_position.y).is_less(0.45)


func _sleep_column() -> void:
	await _watch.frames(get_tree(), SLEEP_FRAMES)
	for crate in _watch.crates:
		assert_bool(crate.sleeping).override_failure_message("%s not asleep" % crate.name).is_true()


# Bottom crate gone: the two others stand on the floor, centres 0.3 and 0.9 m (top 1.2 m, not 1.8).
func _assert_fell_one_level() -> void:
	assert_bool(is_instance_valid(_watch.crates[0])).is_false()
	var lower := _watch.crates[1]
	var upper := _watch.crates[2]
	print("fell: lower %.3f upper %.3f" % [lower.global_position.y, upper.global_position.y])
	assert_float(lower.global_position.y).is_equal_approx(0.3, 0.05)
	assert_float(upper.global_position.y).is_equal_approx(0.9, 0.05)
	assert_float(upper.global_position.y + CrateWatch.SMALL_HALF).is_less(1.3)
