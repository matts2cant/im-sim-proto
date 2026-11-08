extends GdUnitTestSuite
## Unit: the shipped skill table turned into modifiers per tier (no scene tree).

const TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")


func test_untrained_adds_no_modifiers() -> void:
	for skill in TABLE.skills:
		assert_array(skill.modifiers_for(SkillTable.UNTRAINED)).is_empty()


func test_pistols_master_numbers() -> void:
	var values := _values(TABLE.find(&"pistols"), 3)

	assert_float(values[&"pistol_spread_mult"]).is_equal_approx(0.4, 0.0001)
	assert_float(values[&"pistol_settle_time"]).is_equal_approx(0.25, 0.0001)
	assert_float(values[&"pistol_reload_mult"]).is_equal_approx(0.5, 0.0001)
	assert_float(values[&"pistol_damage_mult"]).is_equal_approx(1.3, 0.0001)


func test_pistols_settle_time_per_tier_from_the_untrained_base() -> void:
	var expected: Array[float] = [0.8, 0.6, 0.4, 0.2]
	for tier in 4:
		var attributes := AttributeSet.new()
		for modifier in TABLE.find(&"pistols").modifiers_for(tier):
			attributes.add_modifier(modifier)
		assert_float(attributes.evaluate(&"pistol_settle_time", 0.8)).is_equal_approx(expected[tier], 0.0001)


func test_low_tech_and_medicine_per_tier() -> void:
	var stun: Array[float] = [20.0, 25.0, 30.0, 40.0]
	var heal: Array[float] = [30.0, 45.0, 60.0, 90.0]
	for tier in 4:
		var attributes := AttributeSet.new()
		for skill_id: StringName in [&"low_tech", &"medicine"]:
			for modifier in TABLE.find(skill_id).modifiers_for(tier):
				attributes.add_modifier(modifier)
		assert_float(attributes.evaluate(&"melee_damage_mult", 20.0)).is_equal_approx(stun[tier], 0.0001)
		assert_float(attributes.evaluate(&"medical_heal_mult", 30.0)).is_equal_approx(heal[tier], 0.0001)


func test_tool_skills_only_write_attributes() -> void:
	# Computer has no effects until M11 (ADR 0076).
	assert_array(TABLE.find(&"computer").effects).is_empty()
	assert_float(_values(TABLE.find(&"lockpicking"), 1)[&"lockpick_time_mult"]).is_equal_approx(0.75, 0.0001)


func test_modifiers_carry_the_skill_source_and_tiers_clamp() -> void:
	var skill := TABLE.find(&"low_tech")
	for modifier in skill.modifiers_for(2):
		assert_str(String(modifier.source)).is_equal("skill.low_tech")
	assert_float(_values(skill, 9)[&"melee_damage_mult"]).is_equal_approx(2.0, 0.0001)
	assert_str(TABLE.tier_name(2)).is_equal("Advanced")
	assert_int(SkillTable.clamp_tier(-1)).is_equal(0)


func test_skill_effect_skips_identity_values_but_not_overrides() -> void:
	var effect := SkillEffect.new()
	effect.attribute = &"x"
	effect.op = Modifier.Op.ADD
	effect.tier_values = [0.0, 1.0, 2.0, 3.0]
	assert_object(effect.modifier_for(0, &"s")).is_null()
	assert_float(effect.modifier_for(3, &"s").magnitude).is_equal(3.0)
	effect.op = Modifier.Op.OVERRIDE
	assert_object(effect.modifier_for(0, &"s")).is_not_null()


func _values(skill: SkillData, tier: int) -> Dictionary:
	var values := {}
	for modifier in skill.modifiers_for(tier):
		values[modifier.attribute] = modifier.magnitude
	return values
