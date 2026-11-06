extends GdUnitTestSuite
## Unit: receptron matching (type hierarchy, intensity window, required and blocked tags).

var _receptron: Receptron
var _tags: TagContainer


func before_test() -> void:
	_receptron = Receptron.new()
	_receptron.stimulus_type = &"damage"
	_tags = TagContainer.new()


func test_type_matches_exactly_or_by_hierarchy() -> void:
	assert_bool(_receptron.matches_type(&"damage")).is_true()
	assert_bool(_receptron.matches_type(&"damage.fire")).is_true()
	assert_bool(_receptron.matches_type(&"damaged")).is_false()
	assert_bool(_receptron.matches_type(&"fire")).is_false()

	_receptron.stimulus_type = &"damage.fire"
	assert_bool(_receptron.matches_type(&"damage")).is_false()


func test_empty_type_matches_nothing() -> void:
	_receptron.stimulus_type = &""

	assert_bool(_receptron.matches_type(&"noise")).is_false()


func test_intensity_window_is_inclusive() -> void:
	_receptron.min_intensity = 2.0
	_receptron.max_intensity = 5.0

	assert_bool(_receptron.matches_intensity(1.99)).is_false()
	assert_bool(_receptron.matches_intensity(2.0)).is_true()
	assert_bool(_receptron.matches_intensity(5.0)).is_true()
	assert_bool(_receptron.matches_intensity(5.01)).is_false()


func test_max_intensity_zero_or_less_means_no_upper_bound() -> void:
	_receptron.max_intensity = 0.0
	assert_bool(_receptron.matches_intensity(1000.0)).is_true()

	_receptron.max_intensity = -1.0
	assert_bool(_receptron.matches_intensity(1000.0)).is_true()


func test_required_tags_all_needed_with_hierarchy() -> void:
	_receptron.required_tags = [&"material", &"state.burning"] as Array[StringName]
	_tags.add(&"material.wood")

	assert_bool(_receptron.matches_tags(_tags)).is_false()

	_tags.add(&"state.burning")
	assert_bool(_receptron.matches_tags(_tags)).is_true()


func test_any_blocked_tag_blocks() -> void:
	_receptron.blocked_tags = [&"state.burning", &"state.wet"] as Array[StringName]
	_tags.add(&"material.wood")
	assert_bool(_receptron.matches_tags(_tags)).is_true()

	_tags.add(&"state.wet.soaked")
	assert_bool(_receptron.matches_tags(_tags)).is_false()


func test_missing_tags_component_only_passes_without_required_tags() -> void:
	_receptron.blocked_tags = [&"state.burning"] as Array[StringName]
	assert_bool(_receptron.matches_tags(null)).is_true()

	_receptron.required_tags = [&"material"] as Array[StringName]
	assert_bool(_receptron.matches_tags(null)).is_false()


func test_matches_combines_all_rules() -> void:
	_receptron.min_intensity = 1.0
	_receptron.required_tags = [&"material.wood"] as Array[StringName]
	_tags.add(&"material.wood")

	assert_bool(_receptron.matches(&"damage.fire", 2.0, _tags)).is_true()
	assert_bool(_receptron.matches(&"damage.fire", 0.5, _tags)).is_false()
	assert_bool(_receptron.matches(&"noise", 2.0, _tags)).is_false()


func test_effect_names_are_class_names() -> void:
	_receptron.effects = [AddTagEffect.new(), EmitStimulusEffect.new()] as Array[Effect]

	assert_array(_receptron.effect_names()).contains_exactly(["AddTagEffect", "EmitStimulusEffect"])
