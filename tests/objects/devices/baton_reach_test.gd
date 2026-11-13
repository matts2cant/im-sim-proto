extends GdUnitTestSuite
## Integration: how far the player's baton reaches devices (the sweep: a 0.2 m sphere along the view
## until its front is 1.8 m from the eye, 1.65 m up standing), that it never hits the player's own
## body, that a device broken by it goes offline on the network like a shot one, and that a door's
## wall box takes no damage (it belongs to the door, which bullets and batons cannot open).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const DeviceFixtures := preload("res://tests/objects/devices/device_fixtures.gd")
const DoorHelpers := preload("res://tests/objects/door/door_helpers.gd")
const FIXTURE := "res://tests/objects/devices/fixtures/baton_wall.tscn"
const WALL_LAMP := "res://objects/light_fixture/wall_lamp.tscn"
const CEILING_LAMP := "res://objects/light_fixture/ceiling_lamp.tscn"
const SWITCH := "res://objects/network/switch_desk.tscn"
const CAMERA := "res://objects/camera/security_camera.tscn"
const COMPUTER := "res://objects/computer/computer.tscn"
const WALL_Z := -2.0
const BATON_SLOT := 2
## The wall lamp's collision box: 0.3 m cube centred on its origin's height.
const WALL_LAMP_HALF := 0.15
## The ceiling lamp's collision box bottom, below its origin.
const CEILING_LAMP_DROP := 0.375
## Physics frames from pressing jump to swinging: the apex is at 0.32 s (19 frames).
const JUMP_TO_SWING := 17

var _driver: PlayerDriver
var _weapons: Weapons
var _devices: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


## Measured: standing 0.6 m from the wall, a wall device is hit while its underside is up to about
## 3.4 m high (3.2 m and 3.7 m here, clear of that edge).
func test_standing_swing_reaches_a_wall_device_up_to_about_3_4_m() -> void:
	await _load()
	var low := _spawn(WALL_LAMP, Vector3(-4, 3.2 + WALL_LAMP_HALF, WALL_Z))
	var high := _spawn(WALL_LAMP, Vector3(4, 3.7 + WALL_LAMP_HALF, WALL_Z))
	await _driver.frames(2)

	assert_str(await _swing_at(low, Vector3(-4, 0, WALL_Z + 0.6))).is_equal(String(low.name))
	assert_str(await _swing_at(high, Vector3(4, 0, WALL_Z + 0.6))).is_empty()


## The hub's ceiling lamps hang 3.63 m up: out of a standing swing's reach, in a jumping one's
## (measured up to about 4.3 m at the apex).
func test_jump_swing_reaches_a_ceiling_lamp_a_standing_one_does_not() -> void:
	await _load()
	var lamp := _spawn(CEILING_LAMP, Vector3(0, 3.9 + CEILING_LAMP_DROP, 0))
	await _driver.frames(2)
	var feet := Vector3(0, 0, 0.5)

	assert_str(await _swing_at(lamp, feet)).is_empty()

	_driver.runner.simulate_action_press(&"jump")
	await _driver.frames(JUMP_TO_SWING)
	_driver.runner.simulate_action_release(&"jump")
	await _driver.hold(&"fire", 2)
	await _driver.frames(3)
	assert_str(_last_hit()).is_equal("CeilingLamp")


func test_swing_never_hits_the_players_own_body() -> void:
	await _load()
	var feet := Vector3(0, 0, 0)
	# Straight down through the capsule and the hitboxes: the floor under the feet.
	await _weapons.aim_at(feet, feet + Vector3(0.01, -0.5, 0))
	await _driver.hold(&"fire", 2)
	await _driver.frames(3)
	assert_str(_last_hit()).is_equal("Floor")
	# Level, into empty space: nothing.
	await _wait_ready()
	await _weapons.aim_at(feet, Vector3(0, 1.65, 5))
	await _driver.hold(&"fire", 2)
	await _driver.frames(3)
	assert_str(_last_hit()).is_empty()
	assert_array(EventLog.find(&"actor.damaged")).is_empty()
	assert_array(EventLog.find(&"actor.stunned")).is_empty()


func test_switch_broken_by_the_baton_takes_its_network_offline() -> void:
	await _load()
	var computer_entity := _spawn(COMPUTER, Vector3(-4, 1.45, WALL_Z))
	var switch := _spawn(SWITCH, Vector3(0, 1.0, WALL_Z + 0.08))
	var camera := _spawn(CAMERA, Vector3(4, 2.6, WALL_Z))
	DeviceFixtures.link(computer_entity, switch)
	DeviceFixtures.link(switch, camera)
	await _driver.frames(2)
	var computer := Computer.of(computer_entity)
	assert_array(_status(computer, switch)).contains([DeviceStatus.ONLINE])
	assert_array(_status(computer, camera)).contains([DeviceStatus.ONLINE])

	var feet := Vector3(0, 0, WALL_Z + 1.0)
	for swing in 2:
		assert_str(await _swing_at(switch, feet)).is_equal(String(switch.name))

	assert_bool(Device.of(switch).broken).is_true()
	assert_array(_status(computer, switch)).contains_exactly([DeviceStatus.OFFLINE])
	assert_array(_status(computer, camera)).contains_exactly([DeviceStatus.OFFLINE])
	# The Security app lists the camera offline too.
	assert_array(Array(computer.devices()[0].status)).contains_exactly([DeviceStatus.OFFLINE])


func test_baton_on_a_door_keypad_box_leaves_the_door_locked() -> void:
	_driver = PlayerDriver.new(scene_runner(DoorHelpers.WALL_PLAYER))
	_weapons = Weapons.new(_driver)
	var entity := DoorHelpers.door_entity(_driver.runner.scene())
	var door := Door.of(entity)
	DoorHelpers.add_keypad(entity, &"storage_door", "2817")
	DoorHelpers.lock(entity)
	await _driver.settle()
	await _weapons.equip(BATON_SLOT)
	var box := door.hardware.controls(true)[0]
	var point := DoorHelpers.box_point(door)
	await _weapons.aim_at(Vector3(point.x, 0, DoorHelpers.ORIGIN.z + 1.0), point)

	for swing in 3:
		await _driver.hold(&"fire", 2)
		await _wait_ready()
		assert_str(_last_hit()).is_equal(String(box.name))

	assert_bool(door.is_locked()).is_true()
	assert_bool(door.is_open()).is_false()
	assert_bool(is_instance_valid(box) and box.visible).is_true()
	assert_array(EventLog.find(&"object.damaged")).is_empty()
	assert_array(EventLog.find(&"lock.unlocked")).is_empty()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FIXTURE))
	_weapons = Weapons.new(_driver)
	_devices = _driver.runner.find_child("Devices") as Node3D
	await _driver.settle()
	await _weapons.equip(BATON_SLOT)


func _spawn(scene: String, at: Vector3) -> Node3D:
	var entity := (load(scene) as PackedScene).instantiate() as Node3D
	_devices.add_child(entity, true)
	entity.global_position = at
	return entity


# Stands at `feet`, aims at the entity's Breakable, swings once; returns the name of what was hit
# ("" for nothing).
func _swing_at(entity: Node3D, feet: Vector3) -> String:
	await _weapons.aim_at(feet, Breakable.of(entity).global_position)
	await _driver.hold(&"fire", 2)
	await _wait_ready()
	return _last_hit()


func _last_hit() -> String:
	var swung := EventLog.find(&"weapon.swung")
	return String(swung[-1].data["hit"]) if not swung.is_empty() else "<no swing>"


# Until the swing's cooldown is over (and its CONTACT stimuli delivered), at most 2 s.
func _wait_ready() -> void:
	await _driver.frames(3)
	for frame in 120:
		var state := _driver.player.weapons.state()
		if state == null or state.cooldown <= 0.0:
			break
		await _driver.frames(1)


# What a screen of `computer` shows for `entity`: its status words, online when the computer reaches it.
static func _status(computer: Computer, entity: Node3D) -> PackedStringArray:
	return DeviceStatus.of(entity, computer.device.reaches(entity))
