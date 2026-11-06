extends GdUnitTestSuite
## Integration: HeatEffect heats every heat-reactive component of the entity (group
## HeatEffect.GROUP), including one it has never heard of (defined here).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HEAT_FROM_FIRE: Receptron = preload("res://objects/components/receptrons/heat_from_fire.tres")


## A heat-reactive component HeatEffect knows nothing about.
class HeatProbe:
	extends Node
	var total: float = 0.0
	var causes: Array[int] = []

	func _ready() -> void:
		add_to_group(HeatEffect.GROUP)

	func add_heat(amount: float, cause: Stimulus) -> void:
		total += amount
		causes.append(cause.id)


var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func test_new_heat_reactive_component_gets_the_heat() -> void:
	var entity := Fixtures.entity(_root, "Stove", Vector3.ZERO, [HEAT_FROM_FIRE])
	var probe := HeatProbe.new()
	entity.add_child(probe)
	var spark := Stimulus.make_contact(&"fire", 5.0, entity)

	StimulusSystem.emit(spark)
	await Fixtures.frames(get_tree(), 2)

	assert_float(probe.total).is_equal(5.0)
	assert_array(probe.causes).contains_exactly([spark.id])


func test_every_heat_reactive_component_is_heated_and_others_are_not() -> void:
	var entity := Fixtures.entity(_root, "Stove", Vector3.ZERO, [HEAT_FROM_FIRE])
	var first := HeatProbe.new()
	var second := HeatProbe.new()
	entity.add_child(first)
	entity.add_child(second)
	# Has the method but did not join the group: not heat-reactive.
	var outsider := HeatProbe.new()
	entity.add_child(outsider)
	outsider.remove_from_group(HeatEffect.GROUP)

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 3.0, entity))
	await Fixtures.frames(get_tree(), 2)

	assert_float(first.total).is_equal(3.0)
	assert_float(second.total).is_equal(3.0)
	assert_float(outsider.total).is_equal(0.0)


func test_shipping_components_are_heat_reactive() -> void:
	var entity := Fixtures.entity(_root, "Both", Vector3.ZERO, [HEAT_FROM_FIRE])
	var flammable := Objects.add_flammable(entity, Objects.fire_config(50.0))
	var explosive := Objects.add_explosive(entity, Objects.explosive_config(50.0))

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 4.0, entity))
	await Fixtures.frames(get_tree(), 2)

	assert_bool(flammable.is_in_group(HeatEffect.GROUP)).is_true()
	assert_bool(explosive.is_in_group(HeatEffect.GROUP)).is_true()
	assert_float(flammable.heat()).is_between(3.95, 4.0)
	assert_float(explosive.heat()).is_between(3.95, 4.0)
