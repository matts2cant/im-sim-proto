extends GdUnitTestSuite
## Integration: the debug panel's Stats tab on a minimal entity built in code (any entity with the
## ability components): it builds one control per skill and augmentation, applies changes live and
## follows changes made elsewhere.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")
const STATS_TAB: PackedScene = preload("res://ui/debug_panel/tabs/stats_tab.tscn")

var _world: Node3D
var _entity: Node3D
var _tab: StatsTab


func before_test() -> void:
	EventLog.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_entity = Fixtures.entity(_world, "Subject", Vector3.ZERO, [])
	Abilities.equip(_entity)
	Augmentations.of(_entity).set_physics_process(false)
	_tab = auto_free(STATS_TAB.instantiate()) as StatsTab
	_tab.entity = _entity
	add_child(_tab)
	_tab.refresh()


func test_builds_a_tier_picker_per_skill_and_controls_per_augmentation() -> void:
	var skills: Array[StringName] = [
		&"pistols", &"rifles", &"sniper", &"low_tech", &"medicine", &"computer", &"lockpicking", &"demolition"
	]
	for skill in skills:
		var picker := _tab.find_child("Tier_%s" % skill, true, false) as OptionButton
		assert_object(picker).is_not_null()
		assert_int(picker.item_count).is_equal(4)
	for data in Augmentations.of(_entity).catalog:
		assert_object(_tab.find_child("Installed_%s" % data.id, true, false)).is_not_null()
		assert_object(_tab.find_child("Active_%s" % data.id, true, false)).is_not_null()
	assert_object(_tab.find_child("Refill", true, false)).is_not_null()


func test_picking_a_tier_applies_it_live() -> void:
	var picker := _tab.find_child("Tier_pistols", true, false) as OptionButton

	picker.select(3)
	picker.item_selected.emit(3)

	assert_int(Skills.of(_entity).tier(&"pistols")).is_equal(3)
	assert_float(Attributes.read(_entity, &"pistol_spread_mult", 1.0)).is_equal_approx(0.4, 0.0001)


func test_rifles_and_sniper_pickers_apply_their_tiers_live() -> void:
	for skill: StringName in [&"rifles", &"sniper"]:
		var picker := _tab.find_child("Tier_%s" % skill, true, false) as OptionButton
		picker.select(2)
		picker.item_selected.emit(2)
		assert_int(Skills.of(_entity).tier(skill)).is_equal(2)
	# Rifles Advanced: x0.5 since M13a (ADR 0123).
	assert_float(Attributes.read(_entity, &"rifle_spread_mult", 1.0)).is_equal_approx(0.5, 0.0001)
	assert_float(Attributes.read(_entity, &"sniper_sway_mult", 1.0)).is_equal_approx(0.5, 0.0001)


func test_install_and_active_controls_apply_and_follow_changes() -> void:
	var augs := Augmentations.of(_entity)
	var active := _tab.find_child("Active_cloak", true, false) as CheckButton
	var installed := _tab.find_child("Installed_cloak", true, false) as CheckBox

	active.button_pressed = true
	assert_bool(augs.is_active(&"cloak")).is_true()
	augs.deactivate(&"cloak")
	_tab.refresh()
	assert_bool(active.button_pressed).is_false()

	installed.button_pressed = false
	assert_bool(augs.is_installed(&"cloak")).is_false()
	_tab.refresh()
	assert_bool(active.disabled).is_true()


func test_energy_slider_and_refill() -> void:
	var slider := _tab.find_child("EnergySlider", true, false) as HSlider
	var energy := Energy.of(_entity)

	slider.value = 35.0
	assert_float(energy.current()).is_equal_approx(35.0, 0.001)
	(_tab.find_child("Refill", true, false) as Button).pressed.emit()
	assert_float(energy.current()).is_equal_approx(100.0, 0.001)
	_tab.refresh()
	assert_float(slider.value).is_equal_approx(100.0, 0.001)
