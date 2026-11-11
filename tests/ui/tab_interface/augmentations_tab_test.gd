extends GdUnitTestSuite
## Integration: the Tab interface's Augmentations page (ADR 0111) on a minimal entity with the ability
## components: switches toggle through the F-key path, drain and seconds left, refused at 0 energy,
## greyed slots without an installed augmentation, and the energy draining live while visible.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")
const AUGMENTATIONS_TAB: PackedScene = preload("res://ui/tab_interface/tabs/augmentations_tab.tscn")

var _entity: Node3D
var _augs: Augmentations
var _energy: Energy
var _tab: AugmentationsTab


func before_test() -> void:
	EventLog.clear()
	var world := auto_free(Node3D.new()) as Node3D
	add_child(world)
	_entity = Fixtures.entity(world, "Subject", Vector3.ZERO, [])
	Abilities.equip(_entity, 40.0)
	_augs = Augmentations.of(_entity)
	_augs.set_physics_process(false)
	_energy = Energy.of(_entity)
	_tab = auto_free(AUGMENTATIONS_TAB.instantiate()) as AugmentationsTab
	add_child(_tab)
	_tab.bind(_entity)
	_tab.on_shown()


func test_switches_toggle_like_the_f_keys() -> void:
	var cloak := _switch(1)
	assert_bool(cloak.visible).is_true()

	cloak.button_pressed = true
	assert_bool(_augs.is_active(&"cloak")).is_true()
	assert_bool(cloak.button_pressed).is_true()
	assert_array(EventLog.find(&"augmentation.activated")).has_size(1)

	cloak.button_pressed = false
	assert_bool(_augs.is_active(&"cloak")).is_false()
	# Turned on elsewhere (the F-key): the switch follows.
	_augs.toggle_slot(3)
	_tab.refresh()
	assert_bool(_switch(3).button_pressed).is_true()


func test_drain_and_seconds_left() -> void:
	assert_str(_tab.drain_text()).is_equal("No drain")
	_tab.set_slot_on(1, true)
	_tab.set_slot_on(3, true)

	# Cloak 4 + Speed Enhancement 2 = 6 / s on 40 energy.
	assert_float(_tab.drain_rate()).is_equal_approx(6.0, 0.0001)
	assert_str(_tab.drain_text()).is_equal("6 s left at 6 / s")
	assert_str(_label("Drain").text).is_equal("6 s left at 6 / s")
	assert_str(_tab.slot_side_text(1)).is_equal("4 energy / s  ·  10 s alone")
	assert_str(_tab.slot_side_text(5)).is_equal("1 energy / s")
	assert_str(_label("EnergyValue").text).is_equal("40 / 100")


func test_switching_on_at_zero_energy_is_refused() -> void:
	_energy.set_current(0.0)

	_switch(1).button_pressed = true

	assert_bool(_augs.is_active(&"cloak")).is_false()
	assert_bool(_switch(1).button_pressed).is_false()
	assert_str(_label("Message").text).is_equal(Augmentations.DEPLETED)
	assert_array(EventLog.find(&"augmentation.refused")).has_size(1)


func test_slots_without_an_installed_augmentation_are_greyed() -> void:
	_augs.set_installed(&"run_silent", false)
	_tab.refresh()

	var card := _tab.find_child("Slot2", true, false) as PanelContainer
	assert_float(card.modulate.a).is_less(0.5)
	assert_bool(_switch(2).visible).is_false()
	assert_str(_tab.slot_side_text(2)).is_equal("needs an augmentation canister")
	assert_bool(_tab.set_slot_on(2, true)).is_false()
	assert_bool(_augs.is_active(&"run_silent")).is_false()
	var texts := card.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_array(texts).contains(["Run Silent", "Not installed."])
	assert_float((_tab.find_child("Slot1", true, false) as PanelContainer).modulate.a).is_equal(1.0)


func test_energy_drains_live_while_visible() -> void:
	_augs.set_physics_process(true)
	_tab.set_slot_on(1, true)
	var bar := _tab.find_child("EnergyBar", true, false) as ProgressBar

	# 60 physics frames = 1 s of Cloak at 4 / s.
	for i in 60:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_float(_energy.current()).is_equal_approx(36.0, 0.05)
	assert_str(_label("EnergyValue").text).is_equal("36 / 100")
	assert_float(bar.value).is_equal_approx(0.36, 0.001)


func _switch(slot: int) -> CheckButton:
	return _tab.find_child("Slot%d" % slot, true, false).find_child("Switch", true, false) as CheckButton


func _label(label_name: String) -> Label:
	return _tab.find_child(label_name, true, false) as Label
