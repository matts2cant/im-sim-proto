extends GdUnitTestSuite
## ProximityTriggerConfig (ADR 0138): the shipped tuning (today's numbers) and the tag filter: by
## default every character (tagged or not) sets a mine off; `required_tags` keeps only characters
## with one of them, `ignored_tags` drops characters with one of them.

const CONFIG: ProximityTriggerConfig = preload("res://items/grenades/proximity_trigger.tres")


func test_shipped_tuning() -> void:
	assert_float(CONFIG.arm_time).is_equal(2.0)
	assert_float(CONFIG.radius).is_equal(2.5)
	assert_float(CONFIG.crouched_radius).is_equal(1.0)
	assert_int(CONFIG.check_ticks).is_equal(4)
	assert_int(CONFIG.character_mask).is_equal(PhysicsLayers.CHARACTER_LAYERS)
	assert_int(CONFIG.sight_mask).is_equal(PhysicsLayers.WORLD | PhysicsLayers.OBJECTS)
	assert_float(CONFIG.blink_period).is_equal(1.0)
	assert_float(CONFIG.blink_lit_share).is_equal(0.3)


func test_by_default_every_character_sets_it_off() -> void:
	assert_bool(CONFIG.accepts(null)).is_true()
	assert_bool(CONFIG.accepts(_tags([&"actor.guard"]))).is_true()
	assert_bool(CONFIG.accepts(_tags([]))).is_true()


func test_required_tags_keep_only_matching_characters() -> void:
	var config := ProximityTriggerConfig.new()
	config.required_tags = [&"actor.player"] as Array[StringName]
	assert_bool(config.accepts(_tags([&"actor.player"]))).is_true()
	assert_bool(config.accepts(_tags([&"actor.guard"]))).is_false()
	assert_bool(config.accepts(null)).is_false()


func test_ignored_tags_drop_matching_characters() -> void:
	var config := ProximityTriggerConfig.new()
	config.ignored_tags = [&"actor"] as Array[StringName]
	assert_bool(config.accepts(_tags([&"actor.guard"]))).is_false()
	assert_bool(config.accepts(_tags([&"object.crate"]))).is_true()
	assert_bool(config.accepts(null)).is_true()


func _tags(tags: Array[StringName]) -> TagContainer:
	var container := TagContainer.new()
	for tag in tags:
		container.add(tag)
	return container
