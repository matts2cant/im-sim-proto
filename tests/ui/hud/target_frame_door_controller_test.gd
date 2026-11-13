extends GdUnitTestSuite
## Integration (ADR 0130): the interaction frame on a door controller's wall box. A keycard door
## (tests/objects/fixtures/door_wall_player) whose controller (the card reader boxes) is cabled to a
## powered switch; the player stands 0.8 m in front of the front box, looking at it. The frame names
## the controller, shows its network status (Online, Cut off while the switch is down) and the
## door's lock line ("Locked · keycard"); E without the card says why in a HUD message and leaves
## the door shut.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const DeviceFixtures := preload("res://tests/objects/devices/device_fixtures.gd")

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _entity: StaticBody3D
var _door: Door
var _switch: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(Helpers.WALL_PLAYER))
	_player = _driver.player
	_player.reload_on_reset = false
	_hud = _player.get_node("Hud") as Hud
	_entity = Helpers.door_entity(_driver.runner.scene())
	_door = Door.of(_entity)
	Helpers.add_keycard(_entity, &"frame_test")
	Helpers.lock(_entity)
	# The keycard's boxes (and their default controller) are built on the next frame.
	await _driver.frames(2)
	_switch = DeviceFixtures.device(_entity.get_parent(), "Switch", _entity.position + Vector3(3, 1.5, 1), [], true)
	ActorState.set_tag(_switch, DeviceNetwork.NETWORK_GEAR, true)
	DeviceFixtures.link(_switch, _door.hardware.controller.entity)
	await _driver.settle()
	await _aim()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_frame_shows_the_controllers_status_and_the_doors_lock() -> void:
	var box := _door.hardware.controls(true)[0]
	assert_object(_hud.target_frame.target).is_same(box)
	assert_str(_hud.target_frame.name_text()).is_equal(NetworkSource.display_name(Device.of(box)))
	assert_str(_hud.target_frame.status_text()).is_equal("Online")
	assert_str(_hud.target_frame.lock_text()).is_equal("Locked · keycard")
	# Its switch down: the controller is cut off.
	Powered.of(_switch).on = false
	await _driver.frames(2)
	_hud.target_frame.refresh(_player)
	assert_str(_hud.target_frame.status_text()).is_equal("Cut off")
	assert_str(_hud.target_frame.lock_text()).is_equal("Locked · keycard")


func test_e_on_the_box_without_the_card_says_why() -> void:
	await _driver.hold(&"use", 2)
	await _driver.frames(1)
	_hud.target_frame.refresh(_player)

	assert_bool(_door.is_locked()).is_true()
	assert_bool(_door.is_open()).is_false()
	assert_str(_hud.message_label.text).is_equal("Locked: needs a keycard")


# Stands 0.8 m in front of the front box, looking at its face.
func _aim() -> void:
	var face := Helpers.box_point(_door, true)
	var feet := Vector3(face.x, Helpers.ORIGIN.y, face.z + 0.8)
	_player.load_state(Objects.aiming_state(_player, feet, face))
	await _driver.frames(3)
	_hud.target_frame.refresh(_player)
