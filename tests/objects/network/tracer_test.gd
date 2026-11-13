extends GdUnitTestSuite
## Integration (ADR 0113): a Tracer component on the lab network (network_fixtures.gd: the "Sentry
## tracer" on router Rtr01 watches office and security). It watches a device on a watched subnet
## while its host is up, not disabled and reaches the device; gains are scaled by the user's trace
## gain; a full trace reports an incident at the user's entry point to the alarm controller its
## host reaches and blocks the user's address for the lockout.

const Wait := preload("res://tests/helpers/wait.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const ORIGIN := Vector3(300, 0, -380)

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


func _tracer() -> Tracer:
	return _n["Rtr01"].get_node("Tracer") as Tracer


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _jack() -> NetworkSource:
	return NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)


func test_it_watches_its_subnets_while_its_host_runs_and_reaches_them() -> void:
	var tracer := _tracer()
	assert_object(tracer.config).is_same(Tracer.DEFAULT_CONFIG)
	assert_bool(tracer.watches(_dev("OfficePc"))).is_true()
	assert_bool(tracer.watches(_dev("Console"))).is_true()
	assert_bool(tracer.watches(_dev("FileServer"))).is_false()
	assert_array(Tracer.watching(_dev("Console"))).is_equal([tracer])
	# Cut off: the switch between the host and the console is unpowered.
	Powered.of(_n["SecuritySwitch"]).on = false
	assert_bool(tracer.watches(_dev("Console"))).is_false()
	assert_bool(tracer.watches(_dev("OfficePc"))).is_true()
	Powered.of(_n["SecuritySwitch"]).on = true
	# Host unpowered: nothing is watched.
	Powered.of(_n["Rtr01"]).on = false
	assert_bool(tracer.watches(_dev("OfficePc"))).is_false()
	Powered.of(_n["Rtr01"]).on = true
	# The app stopped (an admin of its host, M12b).
	tracer.running = false
	assert_bool(tracer.watches(_dev("OfficePc"))).is_false()


func test_a_host_switched_off_by_a_command_watches_nothing() -> void:
	var host := Net.body_device(
		_root, "Server", ORIGIN + Vector3(3, 1, 3), [Devices.action_receptron(DeviceSwitch.DISABLE)]
	)
	host.add_child(DeviceSwitch.new())
	Net.link(_n["OfficeSwitch"], host)
	var tracer := Net.add_tracer(host, "Second tracer", [&"office"])
	assert_bool(tracer.watches(_dev("OfficePc"))).is_true()
	(DeviceSwitch.of(host) as DeviceSwitch).set_disabled(true)
	assert_bool(tracer.watches(_dev("OfficePc"))).is_false()


func test_a_running_tool_gains_per_second_times_the_trace_gain() -> void:
	var source := _jack()
	for i in 60:
		Tracer.report_running(_dev("OfficePc"), _user, source, 1.0 / 60.0)
	assert_float(_tracer().trace_of(_user)).is_equal_approx(4.0, 0.01)
	Net.set_tier(_user, 2)
	for i in 60:
		Tracer.report_running(_dev("OfficePc"), _user, source, 1.0 / 60.0)
	assert_float(_tracer().trace_of(_user)).is_equal_approx(4.0 + 2.4, 0.01)
	# Per-frame gains are not logged.
	assert_int(EventLog.find(&"tracer.gain").size()).is_equal(0)
	# A sensitive tracer gains 7 %/s.
	_tracer().config = preload("res://objects/network/tracer_sensitive.tres")
	_tracer().model.config = _tracer().config
	Net.set_tier(_user, 0)
	Tracer.report_running(_dev("OfficePc"), _user, source, 1.0)
	assert_float(_tracer().trace_of(_user)).is_equal_approx(4.0 + 2.4 + 7.0, 0.01)


func test_a_subnet_scan_adds_the_scan_amount() -> void:
	Tracer.report_subnet(get_tree(), &"security", _user, _jack())
	assert_float(_tracer().trace_of(_user)).is_equal_approx(10.0, 0.001)
	Tracer.report_subnet(get_tree(), &"servers", _user, _jack())
	assert_float(_tracer().trace_of(_user)).is_equal_approx(10.0, 0.001)


func test_a_full_trace_reports_the_entry_point_and_blocks_the_address() -> void:
	var source := _jack()
	_tracer().add(95.0, _user, source)
	assert_bool(Tracer.blocks(_dev("OfficePc"), source.address)).is_false()
	Tracer.report(_dev("OfficePc"), Tracer.FAILED_LOGIN, _user, source)
	assert_float(_tracer().trace_of(_user)).is_equal(100.0)
	var full := EventLog.find(&"tracer.full")
	assert_int(full.size()).is_equal(1)
	assert_str(str(full[0].data["address"])).is_equal("10.0.10.40")
	assert_int(int(full[0].data["controllers"])).is_equal(1)
	var command := EventLog.find(&"device.command")[0]
	assert_str(str(command.data["command"])).is_equal(String(Device.INCIDENT))
	assert_str(str(command.data["to"])).is_equal("Alarm")
	# The incident is at the entry point (the jack), not where the user stands.
	assert_vector(command.data["point"] as Vector3).is_equal_approx(_n["Jack"].global_position, Vector3.ONE * 0.001)
	await Wait.frames(get_tree(), 3)
	assert_bool(ActorState.has(_n["Alarm"], Net.ALARMED)).is_true()
	# Blocked on every watched device, for 30 s; not on unwatched ones nor for another address.
	assert_bool(Tracer.blocks(_dev("Console"), source.address)).is_true()
	assert_bool(Tracer.blocks(_dev("FileServer"), source.address)).is_false()
	assert_bool(Tracer.blocks(_dev("Console"), "10.0.10.12")).is_false()
	assert_float(Tracer.lockout_on(_dev("Console"), source.address)).is_equal_approx(30.0, 0.1)
	# A blocked address cannot log in.
	assert_bool(DeviceAccounts.of(_n["OfficePc"]).login_from("kbrandt", "ferry19", _user, source)).is_false()


func test_with_its_host_cut_from_the_alarm_it_still_blocks_but_nothing_rings() -> void:
	Powered.of(_n["SecuritySwitch"]).on = false
	var source := _jack()
	_tracer().add(100.0, _user, source)
	assert_int(int(EventLog.find(&"tracer.full")[0].data["controllers"])).is_equal(0)
	assert_bool(Tracer.blocks(_dev("OfficePc"), source.address)).is_true()


func test_bars_show_tracers_with_trace_or_watching_what_the_user_sees() -> void:
	var seen: Array[Device] = [_dev("OfficePc")]
	assert_array(Tracer.bars_for(get_tree(), _user, seen)).is_equal([_tracer()])
	var none: Array[Device] = [_dev("FileServer")]
	assert_array(Tracer.bars_for(get_tree(), _user, none)).is_empty()
	_tracer().add(5.0, _user, _jack())
	assert_array(Tracer.bars_for(get_tree(), _user, none)).is_equal([_tracer()])


func test_trace_and_lockouts_are_saved() -> void:
	var source := _jack()
	_tracer().add(100.0, _user, source)
	var saved := JSON.to_native(JSON.from_native(_tracer().save_state())) as Dictionary
	_tracer().model.from_dict({})
	assert_float(_tracer().trace_of(_user)).is_equal(0.0)
	_tracer().load_state(saved)
	assert_float(_tracer().trace_of(_user)).is_equal(100.0)
	assert_bool(_tracer().is_blocked(source.address)).is_true()
