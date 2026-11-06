extends GdUnitTestSuite
## Unit + integration: the Interactor's prompt texts and names, and what it resolves under the
## crosshair (pickup, carry, too heavy, use through a hitbox, put down).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const DUMMY := "res://actors/dummy/training_dummy.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_prompt_texts() -> void:
	assert_str(Interactor.prompt_for(Interactor.Kind.PICK_UP, "Multitool", 3)).is_equal("E: pick up Multitool (3)")
	assert_str(Interactor.prompt_for(Interactor.Kind.PICK_UP, "Medkit", 1)).is_equal("E: pick up Medkit")
	assert_str(Interactor.prompt_for(Interactor.Kind.CARRY, "Small crate")).is_equal("E: carry Small crate")
	assert_str(Interactor.prompt_for(Interactor.Kind.USE, "Training dummy", 1, "reset")).is_equal(
		"E: reset Training dummy"
	)
	assert_str(Interactor.prompt_for(Interactor.Kind.TOO_HEAVY, "Large crate")).is_equal("Too heavy")
	assert_str(Interactor.prompt_for(Interactor.Kind.PUT_DOWN, "Small crate")).is_equal("E: put down Small crate")
	assert_str(Interactor.prompt_for(Interactor.Kind.NONE, "x")).is_equal("")


func test_display_names_come_from_metadata_or_the_node_name() -> void:
	var node := Node.new()
	node.name = "SmallCrate2"
	assert_str(Interactor.display_name_of(node)).is_equal("Small crate")
	node.name = "TrainingDummy"
	assert_str(Interactor.display_name_of(node)).is_equal("Training dummy")
	node.set_meta(&"display_name", "Office door")
	assert_str(Interactor.display_name_of(node)).is_equal("Office door")
	node.free()


func test_resolves_pickup_carry_and_too_heavy() -> void:
	await _load()
	var scene := _driver.runner.scene()
	var tool := Items.spawn_pickup(scene, Items.MULTITOOL, Vector3(0, 0.05, -0.9), 3)
	var crate := Objects.spawn(scene, Objects.SMALL_CRATE, Vector3(1.0, 0.3, -0.6))
	var heavy := Objects.spawn(scene, Objects.LARGE_CRATE, Vector3(-1.3, 0.6, -0.8))
	await _driver.frames(20)

	await _look_at(tool.global_position)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.PICK_UP)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Multitool (3)")
	await _look_at(crate.global_position)
	assert_str(_player.interactor.prompt).is_equal("E: carry Small crate")
	await _look_at(heavy.global_position)
	assert_str(_player.interactor.prompt).is_equal("Too heavy")
	await _driver.hold(&"use", 2)
	assert_array(EventLog.find(&"player.pickup_refused")).has_size(1)
	await _look_at(Vector3(0, 1.5, -5.8))
	assert_str(_player.interactor.prompt).is_equal("")


func test_carry_then_put_down_prompt() -> void:
	await _load()
	var crate := Objects.spawn(_driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -1.4))
	await _driver.frames(20)
	await _look_at(crate.global_position)

	await _driver.hold(&"use", 2)
	await _driver.frames(2)

	assert_bool(_player.carry.is_carrying()).is_true()
	assert_str(_player.interactor.prompt).is_equal("E: put down Small crate")
	await _driver.hold(&"use", 2)
	assert_bool(_player.carry.is_carrying()).is_false()


func test_hitbox_resolves_to_its_character() -> void:
	await _load()
	var dummy := Objects.spawn(_driver.runner.scene(), DUMMY, Vector3(0, 0, -1.6)) as TrainingDummy
	await _driver.frames(5)
	await _look_at(dummy.hitboxes.box(&"torso").global_position)

	assert_object(_player.interactor.target).is_same(dummy)
	assert_str(_player.interactor.prompt).is_equal("E: reset Training dummy")


func test_beyond_two_metres_there_is_no_prompt() -> void:
	await _load()
	var tool := Items.spawn_pickup(_driver.runner.scene(), Items.MULTITOOL, Vector3(0, 0.05, -2.6))
	await _driver.frames(20)

	await _look_at(tool.global_position)

	assert_str(_player.interactor.prompt).is_equal("")


func _look_at(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, target))
	await _driver.frames(3)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
