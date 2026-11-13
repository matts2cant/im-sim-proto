extends GdUnitTestSuite
## Integration: the Tags component seeds its container from the inspector list and is saveable.


func test_initial_tags_are_added_on_ready() -> void:
	var tags: Tags = auto_free(Tags.new())
	tags.initial_tags = [&"material.wood", &"object.crate"] as Array[StringName]

	add_child(tags)

	assert_bool(tags.has(&"material")).is_true()
	assert_array(tags.container.tags()).contains_exactly([&"material.wood", &"object.crate"])
	assert_bool(tags.is_in_group(LevelSnapshot.GROUP)).is_true()


func test_save_and_load_state() -> void:
	var tags: Tags = auto_free(Tags.new())
	tags.initial_tags = [&"material.wood"] as Array[StringName]
	add_child(tags)
	tags.add(&"state.burning")
	var saved := tags.save_state()
	tags.remove(&"state.burning")
	tags.add(&"state.wet")

	tags.load_state(saved)

	assert_array(tags.container.tags()).contains_exactly([&"material.wood", &"state.burning"])
