extends GdUnitTestSuite
## Integration (ADR 0115, 0116): a router's rules decide which devices reach which through it, on
## the lab network built from components plus a siren stand-in on the office side (network_fixtures
## add_siren()). Rules are checked in order and the first match wins; a deny rule stops an alarm
## controller (the real AlarmController component on the lab's alarm stand-in) ringing the siren
## across the router and stops the console's command, an allow rule above it re-opens them; a user's
## traffic is judged only by rules that name "you", else by access to the router; edits through the
## Router API are saved and loaded and logged on the router with the editor's address.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(460, 0, -300)
const ALARM_CONFIG := "res://objects/alarm/alarm_controller.tres"
const YOU := RouterRule.Match.YOU
const ANY := RouterRule.Match.ANY
const SUBNET := RouterRule.Match.SUBNET
const DEVICE := RouterRule.Match.DEVICE

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D
var _router: Router


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	Net.add_siren(_root, _n, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))
	_router = Router.of(_n["Rtr01"])


func after_test() -> void:
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _jack() -> NetworkSource:
	return NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _controller() -> AlarmController:
	var controller := AlarmController.new()
	controller.name = "AlarmController"
	controller.config = load(ALARM_CONFIG) as AlarmControllerConfig
	_n["Alarm"].add_child(controller)
	return controller


func test_the_first_matching_rule_wins() -> void:
	var siren := _dev("Siren")
	var alarm := _dev("Alarm")
	assert_bool(alarm.reaches(siren)).is_true()
	_router.rules = [
		RouterRule.make(DEVICE, "Alarm", DEVICE, "10.0.10.30", true),
		RouterRule.make(SUBNET, "security", SUBNET, "office", false),
	]
	# The alarm's own rule comes first; the console falls to the subnet rule.
	assert_bool(alarm.reaches(siren)).is_true()
	assert_bool(_dev("Console").reaches(siren)).is_false()
	assert_bool(_dev("Console").reaches(_dev("OfficePc"))).is_false()
	_router.move_rule(1, -1)
	assert_bool(alarm.reaches(siren)).is_false()
	# Traffic the rules do not name falls to the default.
	assert_bool(_dev("OfficePc").reaches(_dev("Console"))).is_true()
	_router.default_allow = false
	assert_bool(_dev("OfficePc").reaches(_dev("Console"))).is_false()


func test_a_deny_rule_stops_the_alarm_ringing_a_siren_across_the_router() -> void:
	var controller := _controller()
	await _ticks(1)
	_router.add_rule(RouterRule.make(DEVICE, "Alarm", DEVICE, "Siren", false))
	controller.raise(Vector3.ZERO, "test")
	await _ticks(3)
	assert_bool(ActorState.has(_n["Siren"], Net.RUNG)).is_false()
	controller.stop("test")
	# An allow rule above it re-opens the route.
	_router.add_rule(RouterRule.make(SUBNET, "security", DEVICE, "10.0.10.30", true), 0)
	controller.raise(Vector3.ZERO, "test")
	await _ticks(3)
	assert_bool(ActorState.has(_n["Siren"], Net.RUNG)).is_true()


func test_a_deny_rule_stops_a_consoles_command_and_an_allow_reopens_it() -> void:
	var console := _dev("Console")
	var siren := _dev("Siren")
	_router.add_rule(RouterRule.make(DEVICE, "10.0.20.5", ANY, "", false))
	assert_bool(console.send_command(Siren.TEST, siren)).is_false()
	await _ticks(3)
	assert_bool(ActorState.has(_n["Siren"], Net.TESTED)).is_false()
	_router.toggle_rule(0)
	assert_bool(console.send_command(Siren.TEST, siren)).is_true()
	await _ticks(3)
	assert_bool(ActorState.has(_n["Siren"], Net.TESTED)).is_true()
	# The siren logged the command with the console's address.
	var remote := siren.intrusion.device_log.of_kind(DeviceLog.REMOTE)
	assert_int(remote.size()).is_equal(1)
	assert_str(str(remote[0]["address"])).is_equal("10.0.20.5")
	assert_str(str(remote[0]["detail"])).is_equal("command.test")


func test_only_rules_naming_you_judge_a_users_traffic() -> void:
	var console := _dev("Console")
	# Without access, a rule that is not about "you" lets nothing through.
	_router.add_rule(RouterRule.make(ANY, "", ANY, "", true))
	assert_bool(_jack().reaches(get_tree(), console)).is_false()
	# With an account the user passes, whatever other rules say ...
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	_router.add_rule(RouterRule.make(SUBNET, "office", SUBNET, "security", false), 0)
	assert_bool(_jack().reaches(get_tree(), console)).is_true()
	assert_bool(_dev("OfficePc").reaches(console)).is_false()
	# ... unless a rule names "you".
	_router.add_rule(RouterRule.make(YOU, "", DEVICE, "Console", false), 0)
	assert_bool(_jack().reaches(get_tree(), console)).is_false()
	assert_bool(_jack().reaches(get_tree(), _dev("Camera"))).is_true()


func test_edits_are_saved_loaded_and_logged_on_the_router() -> void:
	var source := _jack()
	_router.add_rule(RouterRule.make(DEVICE, "Alarm", DEVICE, "Siren", false), -1, source)
	_router.add_rule(RouterRule.make(YOU, "", SUBNET, "security", true), -1, source)
	_router.move_rule(1, -1, source)
	_router.toggle_rule(1, source)
	var saved := _router.save_state()
	_router.remove_rule(0, source)
	_router.remove_rule(0, source)
	assert_int(_router.rules.size()).is_equal(0)
	_router.load_state(saved)
	assert_int(_router.rules.size()).is_equal(2)
	assert_int(_router.rules[0].from_kind).is_equal(YOU)
	assert_bool(_router.rules[0].allow).is_true()
	assert_str(_router.rules[1].from).is_equal("Alarm")
	assert_bool(_router.rules[1].allow).is_true()
	var edits := _dev("Rtr01").intrusion.device_log.of_kind(DeviceLog.REMOTE)
	assert_int(edits.size()).is_equal(6)
	assert_str(str(edits[0]["address"])).is_equal("10.0.10.40")
	assert_str(str(edits[0]["detail"])).is_equal("firewall: add rule 1")
	assert_int(EventLog.find(&"router.rules").size()).is_equal(6)
