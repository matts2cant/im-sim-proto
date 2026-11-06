extends GdUnitTestSuite
## Integration: the player's act/arms checks read the `state.*` tags, so an AddTag effect (sleep
## gas, handcuffs) blocks input, using things and weapons exactly like an injury does.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_sleep_gas_tag_stops_movement_use_and_weapons() -> void:
	await _load()
	await _armed_at(Vector3.ZERO)
	_add_receptron(&"gas.sleep", ActorState.UNCONSCIOUS)

	StimulusSystem.emit(Stimulus.make_contact(&"gas.sleep", 1.0, _player))
	await _driver.frames(2)
	EventLog.clear()
	await _driver.hold(&"move_forward", 30)
	var result := _player.weapons.trigger()

	assert_bool(_player.is_dead()).is_false()
	assert_float(_player.global_position.distance_to(Vector3.ZERO)).is_less(0.01)
	assert_int(result).is_equal(-1)
	var refused := EventLog.find(&"weapon.refused")
	assert_array(refused).has_size(1)
	assert_str(refused[0].data["reason"]).is_equal("incapacitated")
	assert_str(_player.interactor.prompt).is_empty()


func test_cuffs_tag_stops_weapons_but_not_walking() -> void:
	await _load()
	await _armed_at(Vector3.ZERO)
	_add_receptron(&"restrain.cuffs", ActorState.ARMS_DISABLED)

	StimulusSystem.emit(Stimulus.make_contact(&"restrain.cuffs", 1.0, _player))
	await _driver.frames(2)
	EventLog.clear()
	var result := _player.weapons.trigger()
	await _driver.hold(&"move_back", 30)

	assert_int(result).is_equal(-1)
	var refused := EventLog.find(&"weapon.refused")
	assert_array(refused).has_size(1)
	assert_str(refused[0].data["reason"]).is_equal("arms_disabled")
	assert_float(_player.global_position.distance_to(Vector3.ZERO)).is_greater(0.5)


func test_legs_disabled_tag_forces_a_crawl() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	_add_receptron(&"restrain.snare", ActorState.LEGS_DISABLED)

	StimulusSystem.emit(Stimulus.make_contact(&"restrain.snare", 1.0, _player))
	await _driver.frames(3)

	assert_bool(_player.crouched).is_true()
	assert_float(_player.speed_cap(PlayerMotion.Mode.SPRINT)).is_equal_approx(_player.body.profile.crawl_speed, 0.0001)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


func _armed_at(feet: Vector3) -> void:
	await _driver.place(feet)
	Items.arm(_player)
	await _driver.hold(&"belt_1", 2)
	assert_bool(_player.weapons.is_armed()).is_true()


# Gives the player a receptron that adds `tag` when a `type` stimulus touches it.
func _add_receptron(type: StringName, tag: StringName) -> void:
	var receiver := Fixtures.receiver_of(_player)
	var receptrons := receiver.receptrons.duplicate()
	receptrons.append(Fixtures.receptron(type, [Fixtures.add_tag(tag)]))
	receiver.receptrons = receptrons
