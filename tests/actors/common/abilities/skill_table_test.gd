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


func test_rifles_and_sniper_scale_like_pistols_per_tier() -> void:
	# ADR 0101: spread, reload and damage per tier as Pistols; since M13a (ADR 0123) the Rifles spread
	# steps faster at first (1.0 / 0.65 / 0.5 / 0.4), the Sniper's stays.
	var spreads := {"rifle": [1.0, 0.65, 0.5, 0.4], "sniper": [1.0, 0.8, 0.6, 0.4]}
	var reload: Array[float] = [1.0, 0.85, 0.7, 0.5]
	var damage: Array[float] = [1.0, 1.1, 1.2, 1.3]
	for tier in 4:
		for weapon_class: String in ["rifle", "sniper"]:
			var skill := TABLE.find(&"rifles" if weapon_class == "rifle" else &"sniper")
			var attributes := AttributeSet.new()
			for modifier in skill.modifiers_for(tier):
				attributes.add_modifier(modifier)
			var read := func(stat: String) -> float: return attributes.evaluate(StringName(weapon_class + stat), 1.0)
			var spread: Array = spreads[weapon_class]
			assert_float(read.call("_spread_mult")).is_equal_approx(float(spread[tier]), 0.0001)
			assert_float(read.call("_reload_mult")).is_equal_approx(reload[tier], 0.0001)
			assert_float(read.call("_damage_mult")).is_equal_approx(damage[tier], 0.0001)


func test_sniper_steadies_the_scope_and_rifles_leave_settle_and_sway_alone() -> void:
	var settle: Array[float] = [1.0, 0.8, 0.6, 0.4]
	var sway: Array[float] = [1.0, 0.75, 0.5, 0.25]
	for tier in 4:
		var values := _values(TABLE.find(&"sniper"), tier)
		assert_float(values.get(&"sniper_settle_time", 1.0)).is_equal_approx(settle[tier], 0.0001)
		assert_float(values.get(&"sniper_sway_mult", 1.0)).is_equal_approx(sway[tier], 0.0001)
		var rifles := _values(TABLE.find(&"rifles"), tier)
		assert_bool(rifles.has(&"rifle_settle_time") or rifles.has(&"rifle_sway_mult")).is_false()


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
	# Computer: the deck's tools (M12a, ADR 0113).
	var computer := _values(TABLE.find(&"computer"), 1)
	assert_float(computer[&"deck_crack_time_mult"]).is_equal_approx(0.75, 0.0001)
	assert_float(computer[&"deck_trace_gain_mult"]).is_equal_approx(0.8, 0.0001)
	assert_float(computer[&"deck_max_strength"]).is_equal_approx(1.0, 0.0001)
	assert_float(computer[&"deck_assist"]).is_equal_approx(1.0, 0.0001)
	# M12b: the deck's Wi-Fi range (8 m base) +4 m Trained.
	assert_float(computer[&"deck_wireless_range"]).is_equal_approx(4.0, 0.0001)
	var lockpicking := _values(TABLE.find(&"lockpicking"), 1)
	assert_float(lockpicking[&"lockpick_window_low"]).is_equal_approx(-0.03, 0.0001)
	assert_float(lockpicking[&"lockpick_assist"]).is_equal_approx(1.0, 0.0001)


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


func test_tier_rows_read_the_display_data() -> void:
	# The Skills tab's table (ADR 0111): labels, multipliers, values on a base with units, tier texts.
	var pistols := TABLE.find(&"pistols").tier_rows(4)
	assert_array(Array(pistols[0])).is_equal(["Spread", "x1", "x0.8", "x0.6", "x0.4"])
	assert_array(Array(pistols[1])).is_equal(["Settle", "0.8 s", "0.6 s", "0.4 s", "0.2 s"])
	assert_array(Array(pistols[3])).is_equal(["Damage (pistol 25)", "25", "27.5", "30", "32.5"])
	var medicine := TABLE.find(&"medicine").tier_rows(4)
	assert_array(Array(medicine[0])).is_equal(["Medkit heals", "30", "45", "60", "90"])
	var lockpicking := TABLE.find(&"lockpicking").tier_rows(4)
	assert_array(Array(lockpicking[0])).is_equal(["Sweet spot from", "40 %", "37 %", "34 %", "31 %"])
	assert_array(Array(lockpicking[4])).is_equal(["Lift tolerance", "+0 %", "+1.2 %", "+2.4 %", "+3.6 %"])
	assert_array(Array(lockpicking[7])).is_equal(
		["Assists", "Sound only", "+ tension gauge", "+ captions", "+ clear lock"]
	)
	var computer := TABLE.find(&"computer").tier_rows(4)
	assert_array(Array(computer[0])).is_equal(
		["Crack time", "24 s (Medium)", "18 s (Medium)", "12 s (Medium)", "7.2 s (Medium)"]
	)
	assert_array(Array(computer[2])).is_equal(["Cracks up to", "Weak", "Medium", "Strong", "Strong"])
	assert_array(Array(computer[4])).is_equal(["Wi-Fi range", "8 m", "12 m", "18 m", "25 m"])


func test_every_shipped_effect_has_a_label() -> void:
	for skill in TABLE.skills:
		for effect in skill.effects:
			assert_str(effect.label).override_failure_message(String(effect.attribute)).is_not_empty()


func _values(skill: SkillData, tier: int) -> Dictionary:
	var values := {}
	for modifier in skill.modifiers_for(tier):
		values[modifier.attribute] = modifier.magnitude
	return values
