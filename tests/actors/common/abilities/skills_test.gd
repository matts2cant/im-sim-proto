extends GdUnitTestSuite
## Integration: the Skills component on a minimal entity built in code: tiers become modifiers that
## stack with other sources (injuries), are replaced on change, are logged and saved (ADR 0061).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")

var _world: Node3D
var _entity: Node3D
var _skills: Skills
var _attributes: AttributeSet


func before_test() -> void:
	EventLog.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_entity = Fixtures.entity(_world, "Subject", Vector3.ZERO, [])
	Abilities.equip(_entity)
	_skills = Skills.of(_entity)
	_attributes = Attributes.of(_entity).attribute_set


func test_starts_untrained_with_no_skill_modifiers() -> void:
	for skill in _skills.skill_ids():
		assert_int(_skills.tier(skill)).is_equal(0)
	assert_array(_attributes.modifiers(&"pistol_spread_mult")).is_empty()


func test_set_tier_replaces_the_skill_modifiers_and_logs() -> void:
	_skills.set_tier(&"pistols", 1)
	_skills.set_tier(&"pistols", 3)

	assert_array(_attributes.modifiers(&"pistol_spread_mult")).has_size(1)
	assert_float(_attributes.evaluate(&"pistol_spread_mult", 1.0)).is_equal_approx(0.4, 0.0001)
	var changes := EventLog.find(&"skill.tier_changed")
	assert_array(changes).has_size(2)
	assert_str(changes[1].data["name"]).is_equal("Master")

	_skills.set_tier(&"pistols", 0)
	assert_array(_attributes.modifiers(&"pistol_spread_mult")).is_empty()


func test_skill_modifiers_stack_with_other_sources() -> void:
	# Combat Strength's melee x1.5 (an augmentation source) stacks with Low-Tech Advanced x1.5.
	Augmentations.of(_entity).activate(&"combat_strength")
	_skills.set_tier(&"low_tech", 2)

	assert_float(_attributes.evaluate(&"melee_damage_mult", 20.0)).is_equal_approx(45.0, 0.0001)
	_skills.set_tier(&"low_tech", 0)
	assert_float(_attributes.evaluate(&"melee_damage_mult", 20.0)).is_equal_approx(30.0, 0.0001)


func test_unknown_skills_and_out_of_range_tiers() -> void:
	_skills.set_tier(&"juggling", 2)
	_skills.set_tier(&"medicine", 7)

	assert_int(_skills.tier(&"juggling")).is_equal(0)
	assert_int(_skills.tier(&"medicine")).is_equal(3)


func test_save_and_load_round_trip_re_derive_the_modifiers() -> void:
	_skills.set_tier(&"medicine", 2)
	_skills.set_tier(&"computer", 1)
	var saved := _skills.save_state()
	_skills.set_tier(&"medicine", 0)
	_skills.set_tier(&"lockpicking", 3)

	_skills.load_state(saved)

	assert_int(_skills.tier(&"medicine")).is_equal(2)
	assert_int(_skills.tier(&"computer")).is_equal(1)
	assert_int(_skills.tier(&"lockpicking")).is_equal(0)
	assert_float(_attributes.evaluate(&"medical_heal_mult", 1.0)).is_equal_approx(2.0, 0.0001)
	assert_float(_attributes.evaluate(&"lockpick_assist", 0.0)).is_equal(0.0)
	assert_array(_attributes.modifiers(&"medical_heal_mult")).has_size(1)


func test_a_save_from_before_rifles_and_sniper_loads_them_untrained() -> void:
	# ADR 0101: saves list only the tiers that were set; skills added later are missing and load
	# Untrained, so no migration is needed.
	_skills.set_tier(&"rifles", 3)
	_skills.set_tier(&"sniper", 2)

	_skills.load_state({"tiers": {"pistols": 2, "medicine": 1}})

	assert_int(_skills.tier(&"pistols")).is_equal(2)
	assert_int(_skills.tier(&"rifles")).is_equal(0)
	assert_int(_skills.tier(&"sniper")).is_equal(0)
	assert_float(_attributes.evaluate(&"rifle_spread_mult", 1.0)).is_equal(1.0)
	assert_float(_attributes.evaluate(&"sniper_settle_time", 0.3)).is_equal(0.3)


func test_rifles_and_sniper_tiers_round_trip() -> void:
	_skills.set_tier(&"rifles", 1)
	_skills.set_tier(&"sniper", 3)
	var saved := _skills.save_state()
	_skills.set_tier(&"rifles", 0)
	_skills.set_tier(&"sniper", 0)

	_skills.load_state(saved)

	assert_int(_skills.tier(&"rifles")).is_equal(1)
	assert_int(_skills.tier(&"sniper")).is_equal(3)
	assert_float(_attributes.evaluate(&"rifle_reload_mult", 1.0)).is_equal_approx(0.85, 0.0001)
	assert_float(_attributes.evaluate(&"sniper_damage_mult", 1.0)).is_equal_approx(1.3, 0.0001)
	assert_array(_attributes.modifiers(&"sniper_sway_mult")).has_size(1)
