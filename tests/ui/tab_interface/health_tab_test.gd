extends GdUnitTestSuite
## Integration: the Tab interface's Health page (ADR 0111) on a minimal character built from the body
## components (generality: values, colours, what a disabled part does, current effects from the body
## and the tags) and on the player in a small room (treatment: a medkit on one part with Medicine
## tiers, refused on an unhurt part, Heal all, live updates while visible).

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const HEALTH_TAB: PackedScene = preload("res://ui/tab_interface/tabs/health_tab.tscn")
const HEAL: Receptron = preload("res://actors/common/body/receptrons/heal.tres")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _tab: HealthTab


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_parts_values_colours_and_disabled_text_on_a_minimal_character() -> void:
	var character := _character()
	var body := Characters.body_parts(character)
	body.take_damage(&"damage.blunt", 30.0, &"torso")
	body.take_damage(&"damage.blunt", 200.0, &"arm_l")

	_open(character)

	# The dummy profile: torso 80, arms 50.
	assert_str(_tab.value_text(&"torso")).is_equal("50 / 80")
	assert_str(_tab.value_text(&"arm_l")).is_equal("0 / 50")
	assert_object(_tab.part_color(&"head")).is_equal(HudRules.HEALTHY)
	assert_object(_tab.part_color(&"arm_l")).is_equal(HudRules.DISABLED)
	assert_object(_tab.part_color(&"torso")).is_equal(HudRules.part_color(50.0 / 80.0))
	var zero := _tab.find_child("Part_arm_l", true, false).find_children("*", "Label", true, false)
	var disabled_line := zero.filter(func(label: Label) -> bool: return label.text.begins_with("Disabled"))
	assert_array(disabled_line).has_size(1)
	assert_bool((disabled_line[0] as Label).visible).is_true()
	assert_str((disabled_line[0] as Label).text).contains("Aim spread +3°").contains("Both arms")
	# No inventory: nothing to treat with.
	assert_int(_tab.medkit_count()).is_equal(0)
	assert_bool((_tab.find_child("HealPart", true, false) as Button).disabled).is_true()


func test_current_effects_follow_the_body_and_the_tags() -> void:
	var character := _character()
	var body := Characters.body_parts(character)
	_open(character)
	assert_array(Array(_tab.effect_texts())).is_empty()

	body.take_damage(&"damage.blunt", 200.0, &"leg_l")
	assert_array(Array(_tab.effect_texts())).contains_exactly(["A leg is disabled: move speed x0.6"])
	body.take_damage(&"damage.blunt", 200.0, &"leg_r")
	body.take_damage(&"damage.blunt", 200.0, &"arm_r")
	Characters.tags_of(character).add(&"state.burning")
	assert_array(Array(_tab.effect_texts())).contains_exactly(
		["Both legs disabled: you crawl", "An arm is disabled: aim spread +3°, sway x2", "Burning"]
	)
	# Whatever adds the tag (handcuffs) shows the same effect.
	Characters.tags_of(character).add(ActorState.ARMS_DISABLED)
	assert_array(Array(_tab.effect_texts())).contains(["Both arms disabled: weapons won't fire"])


func test_a_medkit_on_one_part_heals_it_by_30_times_medicine() -> void:
	var player := await _player()
	player.inventory.give(Items.MEDKIT, 3)
	player.body.take_damage(&"damage.blunt", 55.0, &"arm_l")
	player.body.take_damage(&"damage.blunt", 80.0, &"torso")
	_open(player)
	_tab.select_part(&"arm_l")

	assert_float(_tab.heal_per_use()).is_equal_approx(30.0, 0.001)
	assert_bool(_tab.heal_selected()).is_true()

	assert_float(player.body.health(&"arm_l")).is_equal_approx(35.0, 0.001)
	assert_float(player.body.health(&"torso")).is_equal_approx(20.0, 0.001)
	assert_int(_tab.medkit_count()).is_equal(2)
	assert_str((_tab.find_child("Message", true, false) as Label).text).is_equal("Healed 30")
	var used := EventLog.find(&"item.used")
	assert_str(str(used[0].data["part"])).is_equal("arm_l")

	# Medicine Advanced: x2.
	player.skills.set_tier(&"medicine", 2)
	_tab.select_part(&"torso")
	assert_float(_tab.heal_per_use()).is_equal_approx(60.0, 0.001)
	assert_str((_tab.find_child("Treatment", true, false) as Label).text).contains("Medicine: Advanced")
	assert_bool(_tab.heal_selected()).is_true()
	assert_float(player.body.health(&"torso")).is_equal_approx(80.0, 0.001)
	assert_int(_tab.medkit_count()).is_equal(1)


func test_refused_on_an_unhurt_part_and_heal_all_spreads() -> void:
	var player := await _player()
	player.inventory.give(Items.MEDKIT, 2)
	player.body.take_damage(&"damage.blunt", 20.0, &"leg_l")
	_open(player)
	_tab.select_part(&"head")

	assert_bool((_tab.find_child("HealPart", true, false) as Button).disabled).is_true()
	assert_bool(_tab.heal_selected()).is_false()
	assert_int(_tab.medkit_count()).is_equal(2)
	assert_str((_tab.find_child("Message", true, false) as Label).text).is_equal(Items.MEDKIT.refused_message)
	assert_array(EventLog.find(&"item.use_refused")).has_size(1)

	(_tab.find_child("HealAll", true, false) as Button).pressed.emit()

	assert_float(player.body.health(&"leg_l")).is_equal_approx(70.0, 0.001)
	assert_int(_tab.medkit_count()).is_equal(1)
	assert_bool((_tab.find_child("HealAll", true, false) as Button).disabled).is_true()


func test_a_hit_lowers_the_part_live_while_visible() -> void:
	var player := await _player()
	_open(player)
	assert_str(_tab.value_text(&"arm_r")).is_equal("60 / 60")
	var label := _tab.find_child("Part_arm_r", true, false).find_children("*", "Label", true, false)[1] as Label

	var hit := Stimulus.make_contact(&"damage.ballistic", 25.0, player.hitboxes.box(&"arm_r"))
	StimulusSystem.emit(hit)
	for i in 3:
		await get_tree().physics_frame
	# The page refreshes in its own _process (after the frame's process_frame signal).
	await get_tree().process_frame
	await get_tree().process_frame

	assert_float(player.body.health(&"arm_r")).is_equal_approx(35.0, 0.001)
	assert_str(label.text).is_equal("35 / 60")


func _character() -> CharacterBody3D:
	var world := auto_free(Node3D.new()) as Node3D
	add_child(world)
	var extra: Array[Receptron] = [HEAL]
	return Characters.character(world, "Subject", Vector3(0, 0, 300), [], PhysicsLayers.ACTORS, extra)


func _player() -> Player:
	var driver := PlayerDriver.new(scene_runner(ROOM))
	await driver.settle()
	await driver.place(Vector3.ZERO)
	driver.player.input_enabled = false
	return driver.player


func _open(entity: Node) -> void:
	_tab = auto_free(HEALTH_TAB.instantiate()) as HealthTab
	add_child(_tab)
	_tab.bind(entity)
	_tab.on_shown()
