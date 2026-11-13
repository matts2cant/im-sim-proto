extends GdUnitTestSuite
## Integration across the TabPage contract (ADR 0110 host, ADR 0111 pages): the real player's Tab
## interface hosts the Health, Augmentations and Skills pages. They are reached by click and by the
## number keys, each is bound to the player, and they stay live while the world runs: energy drains
## on the Augmentations page, a hit lowers a part on the Health page, and a medkit used on one part
## from the Health page heals that part while the interface stays open and the world keeps running.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const HEALTH := 1
const AUGMENTATIONS := 2
const SKILLS := 3

var _driver: PlayerDriver
var _player: Player
var _tabs: TabInterface


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pages_are_reached_by_click_and_keys_and_bound_to_the_player() -> void:
	await _load()
	await _driver.press(&"tab_interface")

	_tabs.tab_button(HEALTH).pressed.emit()
	assert_bool(_tabs.current_page() is HealthTab).is_true()
	await _driver.press(&"belt_3")
	assert_bool(_tabs.current_page() is AugmentationsTab).is_true()
	await _driver.press(&"belt_4")
	assert_bool(_tabs.current_page() is SkillsTab).is_true()
	_tabs.tab_button(AUGMENTATIONS).pressed.emit()
	assert_int(_tabs.current).is_equal(AUGMENTATIONS)

	assert_object((_tabs.page(HEALTH) as HealthTab).entity).is_same(_player)
	assert_object((_tabs.page(AUGMENTATIONS) as AugmentationsTab).entity).is_same(_player)
	assert_object((_tabs.page(SKILLS) as SkillsTab).entity).is_same(_player)
	assert_str(_tabs.tab_button(HEALTH).text).is_equal("Health")
	assert_str(_tabs.tab_button(SKILLS).text).is_equal("Skills")


func test_energy_drains_live_on_the_augmentations_page() -> void:
	await _load()
	_player.energy.set_current(80.0)
	await _driver.press(&"tab_interface")
	await _driver.press(&"belt_3")
	var page := _tabs.current_page() as AugmentationsTab
	assert_bool(page.set_slot_on(1, true)).is_true()
	await _driver.frames(2)
	var shown_before := page._energy_value.text

	await _driver.frames(60)

	assert_bool(get_tree().paused).is_false()
	assert_float(_player.energy.current()).is_less(80.0)
	assert_str(page._energy_value.text).is_not_equal(shown_before)
	assert_str(page.drain_text()).is_not_equal("No drain")


func test_a_hit_lowers_a_part_on_the_health_page() -> void:
	await _load()
	await _driver.press(&"tab_interface")
	await _driver.press(&"belt_2")
	var page := _tabs.current_page() as HealthTab
	var shown_before := page._values[&"torso"].text

	_player.body.take_damage(&"damage.blunt", 20.0, &"torso")
	await _driver.frames(2)

	assert_bool(_tabs.is_open()).is_true()
	assert_str(page._values[&"torso"].text).is_not_equal(shown_before)
	assert_str(page._values[&"torso"].text).is_equal(page.value_text(&"torso"))


func test_a_medkit_on_one_part_heals_it_while_the_world_runs() -> void:
	await _load()
	_player.inventory.add(Items.MEDKIT, 2)
	_player.body.take_damage(&"damage.blunt", 30.0, &"arm_l")
	_player.body.take_damage(&"damage.blunt", 30.0, &"leg_r")
	var ball := _falling_ball()
	await _driver.press(&"tab_interface")
	await _driver.press(&"belt_2")
	var page := _tabs.current_page() as HealthTab
	var arm_before := _player.body.health(&"arm_l")
	var leg_before := _player.body.health(&"leg_r")
	var ball_y := ball.global_position.y

	page.select_part(&"arm_l")
	assert_bool(page.heal_selected()).is_true()
	await _driver.frames(10)

	assert_float(_player.body.health(&"arm_l")).is_greater(arm_before)
	assert_float(_player.body.health(&"leg_r")).is_equal(leg_before)
	assert_int(_player.inventory.grid.count_of(&"medkit")).is_equal(1)
	assert_bool(_tabs.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_float(ball.global_position.y).is_less(ball_y - 0.1)


func _falling_ball() -> RigidBody3D:
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	_driver.runner.scene().add_child(ball)
	ball.global_position = Vector3(3, 6, 0)
	return ball


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_tabs = TabInterface.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
