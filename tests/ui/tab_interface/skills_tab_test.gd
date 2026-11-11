extends GdUnitTestSuite
## Integration: the Tab interface's Skills page (ADR 0111) on a minimal entity with the ability
## components: the tier table built from the skill data, the TESTING - / + buttons changing the tier
## and the attribute (Skills.set_tier(), the debug panel's path), clamped at Untrained and Master.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")
const SKILLS_TAB: PackedScene = preload("res://ui/tab_interface/tabs/skills_tab.tscn")

var _entity: Node3D
var _skills: Skills
var _tab: SkillsTab


func before_test() -> void:
	EventLog.clear()
	var world := auto_free(Node3D.new()) as Node3D
	add_child(world)
	_entity = Fixtures.entity(world, "Subject", Vector3.ZERO, [])
	Abilities.equip(_entity)
	Augmentations.of(_entity).set_physics_process(false)
	_skills = Skills.of(_entity)
	_tab = auto_free(SKILLS_TAB.instantiate()) as SkillsTab
	add_child(_tab)
	_tab.bind(_entity)
	_tab.on_shown()


func test_lists_every_skill_with_its_tier() -> void:
	for skill in _skills.skill_ids():
		assert_object(_tab.find_child("Skill_%s" % skill, true, false)).is_not_null()
	_skills.set_tier(&"rifles", 2)
	_tab.refresh()
	var row := _tab.find_child("Skill_rifles", true, false)
	var texts := row.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_array(texts).contains_exactly(["Rifles", "Advanced"])


func test_tier_table_of_two_skills_comes_from_the_data() -> void:
	_tab.select_skill(&"medicine")
	var medicine := _tab.table_texts()
	assert_array(Array(medicine[0])).is_equal(["", "Untrained", "Trained", "Advanced", "Master"])
	assert_array(Array(medicine[1])).is_equal(["Medkit heals", "30", "45", "60", "90"])
	assert_int(medicine.size()).is_equal(2)

	_tab.select_skill(&"low_tech")
	var low_tech := _tab.table_texts()
	assert_int(low_tech.size()).is_equal(3)
	assert_array(Array(low_tech[1])).is_equal(["Melee damage", "x1", "x1.25", "x1.5", "x2"])
	assert_array(Array(low_tech[2])).is_equal(["Swing time (baton)", "0.6 s", "0.54 s", "0.48 s", "0.42 s"])
	var title := _tab.find_children("*", "Label", true, false).filter(
		func(label: Label) -> bool: return label.text == "Low-Tech" and label.get_theme_font_size(&"font_size") == 18
	)
	assert_array(title).has_size(1)


func test_plus_and_minus_change_the_tier_and_the_attribute() -> void:
	_tab.select_skill(&"pistols")
	var up := _tab.find_child("TierUp", true, false) as Button
	var down := _tab.find_child("TierDown", true, false) as Button
	assert_bool(down.disabled).is_true()

	up.pressed.emit()

	assert_int(_skills.tier(&"pistols")).is_equal(1)
	assert_float(Attributes.read(_entity, &"pistol_spread_mult", 1.0)).is_equal_approx(0.8, 0.0001)
	assert_array(EventLog.find(&"skill.tier_changed")).has_size(1)
	assert_bool(down.disabled).is_false()

	down.pressed.emit()
	assert_int(_skills.tier(&"pistols")).is_equal(0)
	assert_float(Attributes.read(_entity, &"pistol_spread_mult", 1.0)).is_equal_approx(1.0, 0.0001)


func test_tiers_clamp_at_untrained_and_master() -> void:
	_tab.select_skill(&"lockpicking")
	_tab.change_tier(-1)
	assert_int(_skills.tier(&"lockpicking")).is_equal(SkillTable.UNTRAINED)

	for i in 5:
		_tab.change_tier(1)

	assert_int(_skills.tier(&"lockpicking")).is_equal(SkillTable.MASTER)
	assert_bool((_tab.find_child("TierUp", true, false) as Button).disabled).is_true()
	assert_float(Attributes.read(_entity, &"lockpick_rake", 0.0)).is_equal_approx(1.0, 0.0001)
	assert_array(EventLog.find(&"skill.tier_changed")).has_size(3)
