extends GdUnitTestSuite
## Integration: the Attributes component seeds base values from the inspector and is saveable.


func test_base_values_are_set_on_ready() -> void:
	var attributes: Attributes = auto_free(Attributes.new())
	attributes.base_values = {&"health": 100.0, &"speed": 4.0}

	add_child(attributes)

	assert_float(attributes.value(&"health")).is_equal(100.0)
	assert_float(attributes.value(&"speed")).is_equal(4.0)
	assert_bool(attributes.is_in_group(&"saveable")).is_true()


func test_save_and_load_state() -> void:
	var attributes: Attributes = auto_free(Attributes.new())
	attributes.base_values = {&"speed": 4.0}
	add_child(attributes)
	attributes.attribute_set.add_modifier(Modifier.create(&"speed", Modifier.Op.MULTIPLY, 0.5, &"leg"))
	var saved := attributes.save_state()
	attributes.attribute_set.remove_by_source(&"leg")

	attributes.load_state(saved)

	assert_float(attributes.value(&"speed")).is_equal(2.0)
