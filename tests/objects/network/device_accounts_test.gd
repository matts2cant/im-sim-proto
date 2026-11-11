extends GdUnitTestSuite
## Integration (ADR 0113): DeviceAccounts on the lab network (network_fixtures.gd). A right login
## gives the user the account (no trace); a wrong one adds the tracer's failed-login trace (times the
## user's trace gain) when a tracer watches the device; a down device or a blocked address refuses
## without trace; a password change takes the account away; the Journal's logins are found by code
## id; access is saved.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(300, 0, -340)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))


func after_test() -> void:
	StimulusSystem.clear()


func _accounts(entity_name: String) -> DeviceAccounts:
	return DeviceAccounts.of(_n[entity_name])


func _tracer() -> Tracer:
	return _n["Rtr01"].get_node("Tracer") as Tracer


func test_a_right_login_gives_the_account_without_trace() -> void:
	var accounts := _accounts("OfficePc")
	assert_object(accounts.account("KBrandt ")).is_same(accounts.accounts[0])
	assert_bool(accounts.has_access(_user)).is_false()
	assert_bool(accounts.try_login("kbrandt", "ferry19", _user)).is_true()
	assert_bool(accounts.has_access(_user)).is_true()
	assert_bool(accounts.has_access(_user, "kbrandt")).is_true()
	assert_array(Array(accounts.access_of(_user))).is_equal(["kbrandt"])
	assert_float(_tracer().trace_of(_user)).is_equal(0.0)
	var login := EventLog.find(&"network.login")
	assert_int(login.size()).is_equal(1)
	assert_bool(login[0].data["ok"]).is_true()
	assert_str(str(login[0].data["address"])).is_equal("10.0.10.12")


func test_a_wrong_login_adds_trace_on_a_watched_device_only() -> void:
	assert_bool(_accounts("OfficePc").try_login("kbrandt", "Ferry19", _user)).is_false()
	assert_float(_tracer().trace_of(_user)).is_equal_approx(15.0, 0.001)
	assert_str(str(EventLog.find(&"network.login")[0].data["reason"])).is_equal("wrong")
	# An unknown user counts as a wrong guess.
	assert_bool(_accounts("OfficePc").try_login("root", "x", _user)).is_false()
	assert_float(_tracer().trace_of(_user)).is_equal_approx(30.0, 0.001)
	# Trained: x0.8.
	Net.set_tier(_user, 1)
	_accounts("Console").try_login("dmarsh", "nope", _user)
	assert_float(_tracer().trace_of(_user)).is_equal_approx(42.0, 0.001)
	# The servers subnet is unwatched.
	_accounts("FileServer").try_login("hale", "nope", _user)
	assert_float(_tracer().trace_of(_user)).is_equal_approx(42.0, 0.001)
	assert_int(EventLog.find(&"tracer.gain").size()).is_equal(3)


func test_a_down_device_or_a_blocked_address_refuses_without_trace() -> void:
	var pc := NetworkSource.for_user(_user, Device.of(_n["OfficePc"]), NetworkSource.Kind.BARE)
	_tracer().model.lock(pc.address)
	assert_bool(_accounts("OfficePc").try_login("kbrandt", "ferry19", _user)).is_false()
	assert_str(str(EventLog.find(&"network.login")[0].data["reason"])).is_equal("blocked")
	assert_float(_tracer().trace_of(_user)).is_equal(0.0)
	Powered.of(_n["Rtr01"]).on = false
	# The tracer's host is down: nothing watches, nothing blocks.
	assert_bool(_accounts("OfficePc").try_login("kbrandt", "ferry19", _user)).is_true()
	Powered.of(_n["Rtr01"]).on = true
	Powered.of(_n["Rtr02"]).on = false
	assert_bool(_accounts("Rtr02").try_login("admin", "k3epOut9", _user)).is_false()
	assert_str(str(EventLog.find(&"network.login")[-1].data["reason"])).is_equal("offline")


func test_a_password_change_takes_the_account_away() -> void:
	var accounts := _accounts("Console")
	accounts.grant(_user, "dmarsh")
	accounts.set_password("dmarsh", "tide88")
	assert_bool(accounts.has_access(_user)).is_false()
	assert_bool(accounts.try_login("dmarsh", "harbor77", _user)).is_false()
	assert_bool(accounts.try_login("dmarsh", "tide88", _user)).is_true()
	# Other devices sharing the resources keep their passwords.
	assert_str(_accounts("Rtr01").account("admin").password).is_equal("Gh7vQx2e")


func test_the_journal_knows_a_login_by_its_code_id() -> void:
	var accounts := _accounts("OfficePc")
	assert_str(String(accounts.code_id())).is_equal("office_pc")
	# A computer's credentials id is the default.
	Computer.of(_n["OfficePc"]).credentials_id = &"pc_two"
	assert_str(String(accounts.code_id())).is_equal("pc_two")
	accounts.credentials_id = &"pc2"
	assert_str(String(accounts.code_id())).is_equal("pc2")
	assert_bool(accounts.knows_login(_user, "kbrandt")).is_false()
	var note := LogEntry.make(&"note.night", "Night shift notes", "", "Datapad", {&"pc2": "kbrandt:ferry19"})
	PersonalLog.of(_user).add(note)
	assert_bool(accounts.knows_login(_user, "kbrandt")).is_true()
	assert_str(accounts.known_password(_user, "kbrandt")).is_equal("ferry19")
	assert_str(accounts.known_source(_user, "kbrandt")).is_equal("Night shift notes")


func test_access_and_passwords_are_saved() -> void:
	var accounts := _accounts("Rtr01")
	accounts.grant(_user, "admin")
	accounts.set_password("admin", "N3w")
	accounts.grant(_user, "admin")
	var saved := accounts.save_state()
	var restored := JSON.to_native(JSON.from_native(saved)) as Dictionary
	accounts.set_password("admin", "Other")
	assert_bool(accounts.has_access(_user)).is_false()
	accounts.load_state(restored)
	assert_bool(accounts.has_access(_user, "admin")).is_true()
	assert_str(accounts.account("admin").password).is_equal("N3w")
	assert_bool(accounts.is_admin(_user)).is_true()
