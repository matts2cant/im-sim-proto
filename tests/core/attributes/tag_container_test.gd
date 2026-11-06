extends GdUnitTestSuite
## Unit: hierarchical tag matching, change signals, to_dict round trip.

var _tags: TagContainer


func before_test() -> void:
	_tags = TagContainer.new()


func test_matches_exact_and_descendants_only() -> void:
	assert_bool(TagContainer.matches(&"material.metal", &"material.metal")).is_true()
	assert_bool(TagContainer.matches(&"material.metal", &"material")).is_true()
	assert_bool(TagContainer.matches(&"material.metal.steel", &"material")).is_true()
	assert_bool(TagContainer.matches(&"material", &"material.metal")).is_false()
	assert_bool(TagContainer.matches(&"materials", &"material")).is_false()
	assert_bool(TagContainer.matches(&"material.metal", &"")).is_false()


func test_has_matches_tag_or_any_descendant() -> void:
	_tags.add(&"material.metal")

	assert_bool(_tags.has(&"material")).is_true()
	assert_bool(_tags.has(&"material.metal")).is_true()
	assert_bool(_tags.has(&"material.wood")).is_false()
	assert_bool(_tags.has(&"mat")).is_false()
	assert_bool(_tags.has_exact(&"material")).is_false()


func test_remove_only_removes_exact_tag() -> void:
	_tags.add(&"state")
	_tags.add(&"state.burning")

	assert_bool(_tags.remove(&"state")).is_true()
	assert_bool(_tags.remove(&"state")).is_false()
	assert_bool(_tags.has(&"state")).is_true()
	assert_array(_tags.tags()).contains_exactly([&"state.burning"])


func test_has_all_and_has_any() -> void:
	_tags.add(&"material.wood")
	_tags.add(&"state.burning")

	assert_bool(_tags.has_all([&"material", &"state.burning"] as Array[StringName])).is_true()
	assert_bool(_tags.has_all([&"material", &"state.wet"] as Array[StringName])).is_false()
	assert_bool(_tags.has_all([] as Array[StringName])).is_true()
	assert_bool(_tags.has_any([&"state.wet", &"material"] as Array[StringName])).is_true()
	assert_bool(_tags.has_any([] as Array[StringName])).is_false()


func test_add_and_remove_emit_changed_once() -> void:
	var events: Array = []
	_tags.changed.connect(func(tag: StringName, added: bool) -> void: events.append([tag, added]))

	assert_bool(_tags.add(&"state.burning")).is_true()
	assert_bool(_tags.add(&"state.burning")).is_false()
	_tags.remove(&"state.burning")
	_tags.remove(&"state.burning")

	assert_array(events).is_equal([[&"state.burning", true], [&"state.burning", false]])


func test_to_dict_round_trip() -> void:
	_tags.add(&"material.wood")
	_tags.add(&"state.burning")
	var restored := TagContainer.new()
	restored.add(&"stale")

	restored.from_dict(_tags.to_dict())

	assert_array(restored.tags()).contains_exactly([&"material.wood", &"state.burning"])
	assert_dict(_tags.to_dict()).is_equal({"tags": ["material.wood", "state.burning"]})
