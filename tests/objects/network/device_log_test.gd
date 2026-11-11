extends GdUnitTestSuite
## Integration (ADR 0115, 0116): every device records who used it over the network, with the source
## address (Device.intrusion.device_log), on the lab network built from components: logins and failed
## logins (from the deck's jack, or bare-handed at the computer itself), commands the deck sends with
## access and remote desktops opened from it. Refused attempts (the device down) leave nothing. The
## log is saved with the device.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(540, 0, -300)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))
	_session = DeckSession.of(_user)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _lines(device: Device) -> Array[String]:
	var found: Array[String] = []
	for entry in device.intrusion.device_log.entries:
		found.append(DeviceLog.line(entry))
	return found


func test_logins_and_failed_logins_are_logged_with_the_source_address() -> void:
	var pc := _dev("OfficePc")
	var accounts := DeviceAccounts.of(_n["OfficePc"])
	var jack := NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)
	assert_bool(accounts.login_from("kbrandt", "wrong", _user, jack)).is_false()
	assert_bool(accounts.login_from("kbrandt", "ferry19", _user, jack)).is_true()
	# Bare-handed: the computer's own address.
	assert_bool(accounts.try_login("nobody", "x", _user)).is_false()
	(
		assert_array(_lines(pc))
		. is_equal(
			[
				"failed_login 10.0.10.40 kbrandt",
				"login 10.0.10.40 kbrandt",
				"failed_login 10.0.10.12 nobody",
			]
		)
	)
	# A device that is down refuses before logging anything.
	(_n["Rtr01"].get_node("Powered") as Powered).on = false
	DeviceAccounts.of(_n["Rtr01"]).login_from("admin", "x", _user, jack)
	assert_int(_dev("Rtr01").intrusion.device_log.size()).is_equal(0)
	# Saved with the device.
	var saved := pc.save_state()
	pc.intrusion = DeviceIntrusion.new()
	pc.load_state(saved)
	assert_int(pc.intrusion.device_log.size()).is_equal(3)


func test_deck_commands_and_remote_desktops_are_logged_on_the_device() -> void:
	var console := _dev("Console")
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	DeviceAccounts.of(_n["Console"]).grant(_user, "dmarsh")
	assert_bool(_session.plug(_dev("Jack"), Net.deck_stack())).is_true()
	assert_bool(_session.open_remote(console)).is_true()
	_session.close_remote()
	var camera := _dev("Camera")
	camera.intrusion.grant_exploit(NetworkSource.user_key(_user), Exploit.Access.ADMIN)
	assert_bool(_session.send(Device.DISABLE, camera)).is_true()
	assert_array(_lines(console)).is_equal(["login 10.0.10.40 dmarsh remote desktop"])
	assert_array(_lines(camera)).is_equal(["remote 10.0.10.40 Hacker command.disable"])
