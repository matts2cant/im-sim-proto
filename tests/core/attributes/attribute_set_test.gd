extends GdUnitTestSuite
## Unit: attribute evaluation (add, multiply, override priority and ties), removal, signals, round trip.

const ADD := Modifier.Op.ADD
const MULTIPLY := Modifier.Op.MULTIPLY
const OVERRIDE := Modifier.Op.OVERRIDE

var _set: AttributeSet


func before_test() -> void:
	_set = AttributeSet.new()
	_set.set_base(&"speed", 10.0)


func test_base_value_without_modifiers() -> void:
	assert_float(_set.value(&"speed")).is_equal(10.0)
	assert_float(_set.value(&"unknown")).is_equal(0.0)
	assert_bool(_set.has(&"speed")).is_true()
	assert_bool(_set.has(&"unknown")).is_false()


func test_adds_sum_before_multiplies_multiply() -> void:
	_set.add_modifier(Modifier.create(&"speed", ADD, 2.0))
	_set.add_modifier(Modifier.create(&"speed", MULTIPLY, 0.5))
	_set.add_modifier(Modifier.create(&"speed", ADD, 4.0))
	_set.add_modifier(Modifier.create(&"speed", MULTIPLY, 3.0))

	# (10 + 2 + 4) x 0.5 x 3
	assert_float(_set.value(&"speed")).is_equal_approx(24.0, 0.0001)


func test_modifiers_only_touch_their_attribute() -> void:
	_set.set_base(&"health", 100.0)
	_set.add_modifier(Modifier.create(&"health", MULTIPLY, 0.5))

	assert_float(_set.value(&"speed")).is_equal(10.0)
	assert_float(_set.value(&"health")).is_equal(50.0)


func test_override_replaces_add_and_multiply() -> void:
	_set.add_modifier(Modifier.create(&"speed", ADD, 5.0))
	_set.add_modifier(Modifier.create(&"speed", OVERRIDE, 1.0))
	_set.add_modifier(Modifier.create(&"speed", MULTIPLY, 2.0))

	assert_float(_set.value(&"speed")).is_equal(1.0)


func test_highest_priority_override_wins_regardless_of_order() -> void:
	var high := Modifier.create(&"speed", OVERRIDE, 3.0, &"stun", 10)
	_set.add_modifier(high)
	_set.add_modifier(Modifier.create(&"speed", OVERRIDE, 7.0, &"aug", 1))

	assert_float(_set.value(&"speed")).is_equal(3.0)

	_set.remove_modifier(high)
	assert_float(_set.value(&"speed")).is_equal(7.0)


func test_override_tie_goes_to_most_recently_added() -> void:
	var first := Modifier.create(&"speed", OVERRIDE, 3.0, &"a", 5)
	var second := Modifier.create(&"speed", OVERRIDE, 4.0, &"b", 5)
	_set.add_modifier(first)
	_set.add_modifier(second)

	assert_float(_set.value(&"speed")).is_equal(4.0)

	_set.remove_modifier(second)
	_set.add_modifier(second)
	_set.remove_modifier(first)
	_set.add_modifier(first)
	assert_float(_set.value(&"speed")).is_equal(3.0)


func test_remove_by_source_removes_all_from_that_source() -> void:
	_set.add_modifier(Modifier.create(&"speed", ADD, 5.0, &"leg_damage"))
	_set.add_modifier(Modifier.create(&"speed", MULTIPLY, 0.5, &"leg_damage"))
	_set.add_modifier(Modifier.create(&"speed", ADD, 1.0, &"aug_speed"))

	assert_int(_set.remove_by_source(&"leg_damage")).is_equal(2)
	assert_int(_set.remove_by_source(&"leg_damage")).is_equal(0)
	assert_float(_set.value(&"speed")).is_equal(11.0)
	assert_int(_set.modifiers().size()).is_equal(1)


func test_same_modifier_instance_is_applied_once() -> void:
	var modifier := Modifier.create(&"speed", ADD, 5.0)

	assert_bool(_set.add_modifier(modifier)).is_true()
	assert_bool(_set.add_modifier(modifier)).is_false()
	assert_float(_set.value(&"speed")).is_equal(15.0)
	assert_bool(_set.remove_modifier(modifier)).is_true()
	assert_bool(_set.remove_modifier(modifier)).is_false()


func test_changed_signal_reports_old_and_new_values() -> void:
	var events: Array = []
	_set.changed.connect(
		func(attribute: StringName, old: float, now: float) -> void: events.append([attribute, old, now])
	)
	var modifier := Modifier.create(&"speed", ADD, 5.0)

	_set.set_base(&"speed", 12.0)
	_set.add_modifier(modifier)
	_set.add_modifier(Modifier.create(&"speed", MULTIPLY, 1.0))
	_set.remove_modifier(modifier)

	assert_array(events).is_equal([[&"speed", 10.0, 12.0], [&"speed", 12.0, 17.0], [&"speed", 17.0, 12.0]])


func test_to_dict_round_trip_keeps_values_and_override_order() -> void:
	_set.set_base(&"health", 100.0)
	_set.add_modifier(Modifier.create(&"health", MULTIPLY, 0.5, &"poison"))
	_set.add_modifier(Modifier.create(&"speed", OVERRIDE, 2.0, &"a", 1))
	_set.add_modifier(Modifier.create(&"speed", OVERRIDE, 6.0, &"b", 1))
	var restored := AttributeSet.new()
	var events: Array = []
	restored.changed.connect(func(attribute: StringName, _old: float, _now: float) -> void: events.append(attribute))

	restored.from_dict(_set.to_dict())

	assert_dict(restored.to_dict()).is_equal(_set.to_dict())
	assert_float(restored.value(&"health")).is_equal(50.0)
	assert_float(restored.value(&"speed")).is_equal(6.0)
	assert_float(restored.base(&"speed")).is_equal(10.0)
	assert_array(events).contains_exactly_in_any_order([&"speed", &"health"])
	assert_int(restored.remove_by_source(&"poison")).is_equal(1)
	assert_float(restored.value(&"health")).is_equal(100.0)


func test_to_dict_is_plain_data() -> void:
	_set.add_modifier(Modifier.create(&"speed", OVERRIDE, 2.0, &"stun", 3))

	(
		assert_dict(_set.to_dict())
		. is_equal(
			{
				"bases": {"speed": 10.0},
				"modifiers":
				[{"attribute": "speed", "op": "override", "magnitude": 2.0, "priority": 3, "source": "stun"}],
			}
		)
	)
