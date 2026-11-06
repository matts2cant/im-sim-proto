extends GdUnitTestSuite
## Unit: AttributeSet.evaluate() and Attributes.read(): modifiers applied to a base the consumer
## supplies from its own tuning (ADR 0061).

const ADD := Modifier.Op.ADD
const MULTIPLY := Modifier.Op.MULTIPLY
const OVERRIDE := Modifier.Op.OVERRIDE


func test_evaluate_applies_modifiers_to_the_given_base() -> void:
	var attributes := AttributeSet.new()
	attributes.add_modifier(Modifier.create(&"settle", MULTIPLY, 0.25, &"skill.pistols"))
	attributes.add_modifier(Modifier.create(&"settle", ADD, 0.2, &"other"))

	assert_float(attributes.evaluate(&"settle", 0.8)).is_equal_approx(0.25, 0.0001)
	assert_float(attributes.evaluate(&"unmodified", 1.9)).is_equal_approx(1.9, 0.0001)


func test_evaluate_ignores_the_stored_base_and_value_keeps_using_it() -> void:
	var attributes := AttributeSet.new()
	attributes.set_base(&"speed", 4.0)
	attributes.add_modifier(Modifier.create(&"speed", MULTIPLY, 1.5))

	assert_float(attributes.evaluate(&"speed", 2.0)).is_equal_approx(3.0, 0.0001)
	assert_float(attributes.value(&"speed")).is_equal_approx(6.0, 0.0001)


func test_evaluate_override_wins_over_the_base() -> void:
	var attributes := AttributeSet.new()
	attributes.add_modifier(Modifier.create(&"jump", OVERRIDE, 1.6))

	assert_float(attributes.evaluate(&"jump", 1.0)).is_equal_approx(1.6, 0.0001)


func test_read_falls_back_to_the_base_without_attributes() -> void:
	var bare := auto_free(Node.new()) as Node

	assert_float(Attributes.read(bare, &"jump_apex_height", 1.0)).is_equal(1.0)
	assert_float(Attributes.read(null, &"jump_apex_height", 1.0)).is_equal(1.0)


func test_read_uses_the_entity_attributes_component() -> void:
	var entity := auto_free(Node.new()) as Node
	var component := Attributes.new()
	component.name = "Attributes"
	entity.add_child(component)
	component.attribute_set.add_modifier(Modifier.create(&"mantle_max_height", ADD, 0.6))

	assert_object(Attributes.of(entity)).is_same(component)
	assert_float(Attributes.read(entity, &"mantle_max_height", 1.9)).is_equal_approx(2.5, 0.0001)
