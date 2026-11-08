extends GdUnitTestSuite
## Scenario in the real security wing (inside the hub) with the player, one station after the other
## as a player would do it, driving the components where a screen is involved (keypad, terminal):
## read the code datapad on the entry table -> D1's keypad takes the code -> take the keycard behind
## D1 -> D3 opens with it; take the lockpicks -> pick D2 -> read the login datapad behind D2 -> log in
## at the booth terminal with what the log knows -> disable the turret -> open the vault from the
## terminal (the fail-secure door opens without unlocking). Also: the barrel beside D5 breaks it.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const HUB := "res://levels/hub/hub.tscn"

var _driver: PlayerDriver
var _wing: Node3D
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(HUB))
	_player = _driver.player
	_player.reload_on_reset = false
	_wing = _driver.runner.find_child("SecurityWing") as Node3D
	await _driver.settle()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _node(path: String) -> Node3D:
	return _wing.get_node(path) as Node3D


func _door(door_name: String) -> Door:
	return Door.of(_node("Doors/" + door_name))


## Puts the player at wing-local `feet` facing wing-local `look` and lets it land.
func _stand(feet: Vector3, look: Vector3) -> void:
	var to := look - feet
	await _driver.place(_wing.to_global(feet), atan2(-to.x, -to.z))


## E on a datapad: reads it into the log; the reading overlay (a pause screen) is closed again.
func _read(path: String) -> void:
	(_node(path).get_node("Readable") as Readable).use(_player)
	for overlay: Node in _player.find_children("*", "ReadingOverlay", true, false):
		(overlay as ReadingOverlay).close()
	await _driver.frames(1)


func _wait_open(door: Door) -> void:
	for i in 90:
		if door.is_open() and not door.is_moving():
			return
		await _driver.frames(1)


func test_code_keycard_login_turret_and_vault() -> void:
	# The code datapad on the entry table.
	await _stand(Vector3(-4, 0, 1.4), Vector3(-4.4, 1, 0.36))
	await _read("Items/ClosetCode")
	var keypad := _node("Doors/D1Keypad").get_node("KeypadLock") as KeypadLock
	assert_str(keypad.reminder(_player)).contains("5309")

	# D1: the keypad takes the code the log reminds the player of (the keypad screen submits it).
	await _stand(Vector3(-6.4, 0, 5.0), Vector3(-6.4, 1.2, 6.25))
	assert_str(_door("D1Keypad").prompt(_player)).is_equal("E: enter code")
	assert_bool(keypad.submit(PersonalLog.of(_player).known_code(keypad.code_id()), _player)).is_true()
	await _wait_open(_door("D1Keypad"))
	assert_bool(_door("D1Keypad").is_open()).is_true()

	# The keycard on D1's shelf.
	await _stand(Vector3(-6.25, 0, 7.6), Vector3(-6.25, 1, 8.74))
	assert_bool(_player.inventory.pick_up(ItemPickup.of(_node("Items/Keycard")))).is_true()

	# D3 opens with it.
	await _stand(Vector3(-0.4, 0, 5.0), Vector3(-0.4, 1.2, 6.25))
	assert_str(_door("D3Keycard").prompt(_player)).is_equal("E: open (keycard)")
	assert_bool(_door("D3Keycard").use(_player)).is_true()
	await _wait_open(_door("D3Keycard"))
	assert_bool(_door("D3Keycard").is_open()).is_true()

	# The lockpicks on the table, then D2: hold the pick on the lock until it gives.
	await _stand(Vector3(-3.6, 0, 1.4), Vector3(-3.6, 1, 0.36))
	assert_bool(_player.inventory.pick_up(ItemPickup.of(_node("Items/Lockpick")))).is_true()
	await _stand(Vector3(-3.4, 0, 5.0), Vector3(-3.4, 1.2, 6.25))
	var pick := _node("Doors/D2Mechanical").get_node("MechanicalLock") as MechanicalLock
	assert_bool(pick.accepts_tool(&"lockpick")).is_true()
	var picked := false
	for i in 600:
		if pick.tool_hold(_player, 1.0 / 60.0):
			picked = true
			break
		await _driver.frames(1)
	assert_bool(picked).is_true()
	await _wait_open(_door("D2Mechanical"))
	assert_bool(_door("D2Mechanical").is_open()).is_true()

	# The login datapad behind D2.
	await _stand(Vector3(-3.25, 0, 7.6), Vector3(-3.25, 1, 8.74))
	await _read("Items/BoothLogin")

	# The booth terminal: the log knows the login ("Fill in"), the player logs in.
	await _stand(Vector3(-0.25, 0, 8.1), Vector3(-0.25, 1.45, 8.99))
	EventLog.clear()
	var terminal := Terminal.of(_node("Devices/Terminal"))
	var known := terminal.known_credentials(_player)
	assert_object(known).is_not_null()
	assert_str(terminal.credentials_source(_player)).is_equal("Booth login")
	assert_bool(terminal.log_in(known.user, known.password, _player)).is_true()
	assert_bool(EventLog.find(&"terminal.login")[0].data["ok"]).is_true()

	# Disable the turret, then open the vault.
	var turret := Turret.of(_node("Devices/Turret"))
	assert_bool(terminal.send(Device.DISABLE, Device.of(_node("Devices/Turret")))).is_true()
	await _driver.frames(3)
	assert_bool(turret.disabled).is_true()
	assert_bool(turret.is_active()).is_false()
	var vault := _door("VaultDoor")
	assert_bool(terminal.send(Device.OPEN, Device.of(_node("Doors/VaultDoor")))).is_true()
	await _driver.frames(3)
	await _wait_open(vault)
	assert_bool(vault.is_open()).is_true()
	# An authorised open: still locked, it locks again once closed.
	assert_bool(vault.is_locked()).is_true()
	assert_array(EventLog.find(&"door.opened")).is_not_empty()
	assert_str(String(EventLog.find(&"door.opened")[0].target)).is_equal("VaultDoor")


func test_the_barrel_beside_d5_breaks_it() -> void:
	await _stand(Vector3(0, 0, 1.0), Vector3(6.7, 0.5, 5.2))
	var d5 := _door("D5Breakable")
	assert_bool(d5.is_open()).is_false()
	var barrel := _node("Props/Barrel")
	# A pistol round's worth of ballistic damage at a time until it goes off (as shots would).
	for i in 4:
		if not is_instance_valid(barrel):
			break
		StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 25.0, barrel, _player))
		await _driver.frames(3)
	await _driver.frames(30)

	assert_bool(d5.broken).is_true()
	assert_bool(d5.is_open()).is_true()
	# D4 (not breakable, 4.3 m away) is still shut.
	assert_bool(_door("D4Electronic").is_open()).is_false()
