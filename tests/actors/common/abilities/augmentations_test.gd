extends GdUnitTestSuite
## Integration: Energy and Augmentations on a minimal entity built in code (Tags, Attributes,
## StimulusReceiver; no player): drain per augmentation, depletion, refusals, modifiers and tags while
## on, slots, uninstalling, energy restore through the `energy` receptron, saving (ADR 0061).
## Drain is stepped by calling the component's physics step with a fixed delta.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")

var _world: Node3D
var _entity: Node3D
var _energy: Energy
var _augs: Augmentations
var _messages: Array[String] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_messages = []
	_world = auto_free(Node3D.new())
	add_child(_world)
	_entity = Fixtures.entity(_world, "Subject", Vector3.ZERO, [])
	Abilities.equip(_entity)
	_energy = Energy.of(_entity)
	_augs = Augmentations.of(_entity)
	_augs.set_physics_process(false)
	_augs.message.connect(func(text: String) -> void: _messages.append(text))


func test_each_toggle_drains_at_its_rate() -> void:
	var rates := {&"cloak": 4.0, &"run_silent": 1.5, &"speed_enhancement": 2.0, &"regeneration": 5.0}
	for id: StringName in rates:
		_energy.set_current(100.0)
		assert_bool(_augs.activate(id)).is_true()
		_step(2.0)
		assert_float(_energy.current()).is_equal_approx(100.0 - 2.0 * float(rates[id]), 0.01)
		_augs.deactivate(id)
	assert_array(EventLog.find(&"augmentation.activated")).has_size(4)
	assert_array(EventLog.find(&"augmentation.deactivated")).has_size(4)


func test_drains_add_up_and_passive_costs_nothing() -> void:
	assert_bool(_augs.is_active(&"combat_strength")).is_true()
	_augs.activate(&"cloak")
	_augs.activate(&"run_silent")

	assert_float(_augs.drain_rate()).is_equal_approx(5.5, 0.0001)
	_step(4.0)
	assert_float(_energy.current()).is_equal_approx(78.0, 0.01)


func test_reaching_zero_switches_every_toggle_off_with_the_message() -> void:
	_energy.set_current(3.0)
	_augs.activate(&"cloak")
	_augs.activate(&"speed_enhancement")

	_step(0.3)
	assert_array(_augs.active_ids()).contains([&"cloak", &"speed_enhancement"])
	_step(0.4)

	assert_float(_energy.current()).is_equal(0.0)
	assert_array(_augs.active_ids()).is_equal([&"combat_strength"])
	assert_array(_messages).is_equal(["Energy depleted"])
	var off := EventLog.find(&"augmentation.deactivated")
	assert_array(off).has_size(2)
	assert_str(off[0].data["reason"]).is_equal("depleted")
	assert_bool(Fixtures.tags_of(_entity).has(&"state.cloaked")).is_false()


func test_switching_on_with_no_energy_fails_with_the_message() -> void:
	_energy.set_current(0.0)

	assert_bool(_augs.toggle(&"regeneration")).is_false()

	assert_bool(_augs.is_active(&"regeneration")).is_false()
	assert_array(_messages).is_equal(["Energy depleted"])
	assert_str(EventLog.find(&"augmentation.refused")[0].data["reason"]).is_equal("no_energy")


func test_cloak_adds_and_removes_the_cloaked_tag() -> void:
	_augs.toggle(&"cloak")
	assert_bool(Fixtures.tags_of(_entity).has(&"state.cloaked")).is_true()

	_augs.toggle(&"cloak")
	assert_bool(Fixtures.tags_of(_entity).has(&"state.cloaked")).is_false()


func test_modifiers_apply_while_on_and_stack_with_other_sources() -> void:
	var attributes := Attributes.of(_entity).attribute_set
	attributes.add_modifier(Modifier.create(&"move_speed_mult", Modifier.Op.MULTIPLY, 0.6, &"body_parts"))

	_augs.activate(&"speed_enhancement")
	assert_float(attributes.evaluate(&"move_speed_mult", 1.0)).is_equal_approx(0.9, 0.0001)
	assert_float(Attributes.read(_entity, &"jump_apex_height", 1.0)).is_equal_approx(1.6, 0.0001)
	assert_float(Attributes.read(_entity, &"mantle_max_height", 1.9)).is_equal_approx(2.5, 0.0001)

	_augs.deactivate(&"speed_enhancement")
	assert_float(attributes.evaluate(&"move_speed_mult", 1.0)).is_equal_approx(0.6, 0.0001)
	assert_float(Attributes.read(_entity, &"jump_apex_height", 1.0)).is_equal(1.0)


func test_combat_strength_is_passive_while_installed() -> void:
	assert_float(Attributes.read(_entity, &"carry_mass_limit", 20.0)).is_equal_approx(70.0, 0.0001)
	assert_bool(_augs.toggle(&"combat_strength")).is_true()

	_augs.set_installed(&"combat_strength", false)

	assert_float(Attributes.read(_entity, &"carry_mass_limit", 20.0)).is_equal(20.0)
	assert_bool(_augs.is_active(&"combat_strength")).is_false()


func test_slots_map_to_the_toggles() -> void:
	assert_str(String(_augs.in_slot(1).id)).is_equal("cloak")
	assert_str(String(_augs.in_slot(4).id)).is_equal("regeneration")
	assert_object(_augs.in_slot(5)).is_null()

	assert_bool(_augs.toggle_slot(3)).is_true()
	assert_bool(_augs.is_active(&"speed_enhancement")).is_true()
	assert_bool(_augs.toggle_slot(5)).is_false()


func test_uninstalling_switches_off_and_blocks_activation() -> void:
	_augs.activate(&"run_silent")

	_augs.set_installed(&"run_silent", false)

	assert_bool(_augs.is_active(&"run_silent")).is_false()
	assert_float(Attributes.read(_entity, &"footstep_noise_mult", 1.0)).is_equal(1.0)
	assert_bool(_augs.activate(&"run_silent")).is_false()
	assert_str(EventLog.find(&"augmentation.refused")[0].data["reason"]).is_equal("not_installed")


func test_energy_stimulus_restores_and_is_refused_when_full() -> void:
	_energy.set_current(60.0)

	StimulusSystem.emit_now(Stimulus.make_contact(&"energy", 25.0, _entity, _entity))
	assert_float(_energy.current()).is_equal_approx(85.0, 0.001)
	StimulusSystem.emit_now(Stimulus.make_contact(&"energy", 25.0, _entity, _entity))

	assert_float(_energy.current()).is_equal_approx(100.0, 0.001)
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"energy", 25.0, _entity, _entity))).is_false()


func test_energy_spend_and_fraction() -> void:
	_energy.set_current(30.0)

	assert_float(_energy.spend(50.0)).is_equal_approx(30.0, 0.0001)
	assert_bool(_energy.is_empty()).is_true()
	_energy.refill()
	assert_float(_energy.fraction()).is_equal(1.0)
	_energy.set_current(250.0)
	assert_float(_energy.current()).is_equal(100.0)


func test_save_and_load_round_trip_installed_active_and_energy() -> void:
	_augs.activate(&"cloak")
	_augs.set_installed(&"regeneration", false)
	_energy.set_current(42.0)
	var saved_augs := _augs.save_state()
	var saved_attributes := Attributes.of(_entity).save_state()
	var saved_tags := (_entity.get_node("Tags") as Tags).save_state()

	_augs.deactivate(&"cloak")
	_augs.set_installed(&"regeneration", true)
	_augs.activate(&"speed_enhancement")
	_energy.set_current(90.0)
	Attributes.of(_entity).load_state(saved_attributes)
	(_entity.get_node("Tags") as Tags).load_state(saved_tags)
	_augs.load_state(saved_augs)

	assert_array(_augs.active_ids()).is_equal([&"cloak", &"combat_strength"])
	assert_bool(_augs.is_installed(&"regeneration")).is_false()
	assert_float(_energy.current()).is_equal_approx(42.0, 0.0001)
	assert_bool(Fixtures.tags_of(_entity).has(&"state.cloaked")).is_true()
	assert_float(Attributes.read(_entity, &"move_speed_mult", 1.0)).is_equal(1.0)
	var cloak_mods := Attributes.of(_entity).attribute_set.modifiers(&"carry_mass_limit")
	assert_array(cloak_mods).has_size(1)


# Steps the drain in 0.1 s ticks.
func _step(seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		_augs._physics_process(0.1)
