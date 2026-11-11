extends GdUnitTestSuite
## Integration (ADR 0113): a DeckSession and its IcebreakerTool on a minimal user entity (no player:
## network_fixtures.gd user()) plugged into the lab network. Discovery: the own subnet after a 2 s
## scan (+10 % on the tracer watching it), the gateway at once, the subnets behind it hidden until it
## is hacked, then chained; seen devices stay on the map when out of reach. The Icebreaker: a crack
## gives the account and is learned into the PersonalLog (the Journal lists it); stopping keeps the
## progress on the deck, resuming continues, a changed password starts over; a lockout stops it.
## Tethering, a maintenance port, commands with an account and a remote desktop.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(340, 0, -300)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession
var _ice: IcebreakerTool
var _stack: ItemStack


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))
	_session = DeckSession.of(_user)
	_ice = IcebreakerTool.of(_user)
	_stack = Net.deck_stack()


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _map() -> Array[String]:
	var found: Array[String] = []
	for each in _session.map_devices():
		found.append(String(each.entity.name))
	return found


func _tracer() -> Tracer:
	return _n["Fw01"].get_node("Tracer") as Tracer


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


# Plugs into the jack and waits out every scan; fast scans unless `real_scan`.
func _plug_jack(real_scan: bool = false) -> void:
	if not real_scan:
		_session.config = _session.config.duplicate() as DeckConfig
		_session.config.scan_time = 0.1
	assert_bool(_session.plug(_dev("Jack"), _stack)).is_true()
	await _seconds(_session.config.scan_time + 0.1)


func test_plugging_into_a_jack_scans_the_own_subnet_and_shows_its_gateway() -> void:
	await _plug_jack(true)
	assert_bool(_session.is_plugged()).is_true()
	assert_str(_session.source.address).is_equal("10.0.10.40")
	var plugged := EventLog.find(&"deck.plugged")
	assert_str(str(plugged[0].data["port"])).is_equal("JACK")
	assert_array(_map()).contains_exactly_in_any_order(["Jack", "OfficeSwitch", "OfficePc", "Fw01"])
	# One scan of the office subnet, +10 % on the Sentry tracer (it watches office).
	assert_int(EventLog.find(&"deck.scan").size()).is_equal(1)
	assert_float(_tracer().trace_of(_user)).is_between(0.0, 10.0)
	assert_array(_stack.state[DeckSession.SCANNED] as Array).is_equal(["office"])
	# Behind the gateway: no node at all.
	assert_bool(_map().has("Console")).is_false()
	assert_int(_session.hidden_routes(_dev("Fw01"))).is_equal(1)


func test_the_gateway_shows_before_the_scan_ends() -> void:
	assert_bool(_session.plug(_dev("Jack"), _stack)).is_true()
	await _seconds(0.5)
	assert_array(_map()).is_equal(["Fw01"])


func test_hacked_gateways_reveal_the_subnets_behind_them_in_a_chain() -> void:
	await _plug_jack()
	var note := LogEntry.make(&"note.fw", "Router notes", "", "Datapad", {&"router.admin": "admin:Gh7vQx2e"})
	PersonalLog.of(_user).add(note)
	assert_bool(_session.log_in(_dev("Fw01"), "admin")).is_false()
	DeviceAccounts.of(_n["Fw01"]).credentials_id = &"router"
	var before := _tracer().trace_of(_user)
	assert_bool(_session.log_in(_dev("Fw01"), "admin")).is_true()
	# A known login adds no trace (the next scan does).
	assert_float(_tracer().trace_of(_user)).is_equal(before + 10.0)
	await _seconds(0.3)
	assert_array(_map()).contains(["SecuritySwitch", "Console", "Camera", "Alarm", "Fw02"])
	assert_bool(_map().has("FileServer")).is_false()
	assert_int(_session.hidden_routes(_dev("Fw01"))).is_equal(0)
	assert_int(_session.hidden_routes(_dev("Fw02"))).is_equal(1)
	DeviceAccounts.of(_n["Fw02"]).grant(_user, "admin")
	_session.refresh()
	await _seconds(0.3)
	assert_array(_map()).contains(["ServerSwitch", "FileServer"])
	# Seen devices stay on the map when out of reach.
	Powered.of(_n["SecuritySwitch"]).on = false
	_session.refresh()
	assert_array(_map()).contains(["Console", "FileServer"])
	assert_bool(_session.reached_devices().has(_dev("Console"))).is_false()
	assert_bool(_session.is_online(_dev("Console"))).is_false()


func test_a_crack_gives_the_account_and_is_learned_into_the_journal() -> void:
	await _plug_jack()
	var trace_before := _tracer().trace_of(_user)
	assert_bool(_ice.can_crack(_dev("OfficePc"), "kbrandt")).is_true()
	assert_float(_ice.crack_time(_dev("OfficePc"), "kbrandt")).is_equal(10.0)
	assert_bool(_ice.start(_dev("OfficePc"), "kbrandt")).is_true()
	await _seconds(5.0)
	assert_int(_ice.job.locked_letters()).is_between(3, 4)
	await _seconds(5.1)
	assert_bool(_ice.is_running()).is_false()
	assert_bool(_ice.job.is_done()).is_true()
	assert_bool(DeviceAccounts.of(_n["OfficePc"]).has_access(_user, "kbrandt")).is_true()
	# 10 s at 4 %/s (Untrained) on the watched PC; drain does not start while it runs.
	assert_float(_tracer().trace_of(_user)).is_equal_approx(trace_before + 40.0, 0.5)
	var codes := JournalRules.codes(PersonalLog.of(_user).book)
	assert_int(codes.size()).is_equal(1)
	assert_str(String(codes[0]["code_id"])).is_equal("office_pc.kbrandt")
	assert_str(str(codes[0]["value"])).is_equal("kbrandt / ferry19")
	assert_str(str(codes[0]["label"])).is_equal("OFFICE-PC (kbrandt)")
	assert_bool(DeviceAccounts.of(_n["OfficePc"]).knows_login(_user, "kbrandt")).is_true()
	assert_int(EventLog.find(&"deck.cracked").size()).is_equal(1)
	# Nothing left to crack there.
	assert_bool(_ice.start(_dev("OfficePc"), "kbrandt")).is_false()
	# A Medium password is too strong for an untrained user; Trained cracks it.
	assert_bool(_ice.can_crack(_dev("Fw01"), "admin")).is_false()
	assert_bool(_ice.start(_dev("Fw01"), "admin")).is_false()
	Net.set_tier(_user, 1)
	assert_bool(_ice.can_crack(_dev("Fw01"), "admin")).is_true()


func test_stopping_keeps_progress_and_resuming_continues_unless_the_password_changed() -> void:
	Net.set_tier(_user, 1)
	await _plug_jack()
	DeviceAccounts.of(_n["Fw01"]).grant(_user, "admin")
	_session.refresh()
	await _seconds(0.3)
	# Trained, Medium: 18 s.
	assert_bool(_ice.start(_dev("Console"), "dmarsh")).is_true()
	await _seconds(4.5)
	_ice.stop()
	var kept := _ice.saved_progress(_dev("Console"), "dmarsh")
	assert_float(kept).is_equal_approx(0.25, 0.01)
	var cracks := _stack.state[IcebreakerTool.CRACKS] as Dictionary
	assert_int(cracks.size()).is_equal(1)
	await _seconds(1.0)
	assert_float(_ice.saved_progress(_dev("Console"), "dmarsh")).is_equal(kept)
	assert_bool(_ice.resume()).is_true()
	assert_float(_ice.job.progress).is_equal_approx(kept, 0.001)
	assert_str(str(EventLog.find(&"deck.icebreaker")[-1].data["action"])).is_equal("resume")
	await _seconds(1.0)
	_ice.stop()
	# The password changed: the kept progress is lost.
	DeviceAccounts.of(_n["Console"]).set_password("dmarsh", "tide88")
	assert_float(_ice.saved_progress(_dev("Console"), "dmarsh")).is_equal(0.0)
	assert_bool(_ice.start(_dev("Console"), "dmarsh")).is_true()
	assert_float(_ice.job.progress).is_equal(0.0)
	assert_str(_ice.job.password).is_equal("tide88")


func test_a_full_trace_stops_the_icebreaker_and_keeps_its_progress() -> void:
	await _plug_jack()
	assert_bool(_ice.start(_dev("OfficePc"), "kbrandt")).is_true()
	await _seconds(2.0)
	_tracer().add(100.0, _user, _session.source)
	await _seconds(0.1)
	assert_bool(_ice.is_running()).is_false()
	assert_str(str(EventLog.find(&"deck.icebreaker")[-1].data["action"])).is_equal("lost")
	assert_float(_ice.saved_progress(_dev("OfficePc"), "kbrandt")).is_greater(0.15)
	assert_bool(_session.is_blocked(_dev("OfficePc"))).is_true()
	assert_bool(_ice.start(_dev("OfficePc"), "kbrandt")).is_false()
	assert_bool(_session.log_in(_dev("OfficePc"), "kbrandt")).is_false()


func test_walking_away_unplugs_and_stops_the_tools() -> void:
	await _plug_jack()
	assert_bool(_ice.start(_dev("OfficePc"), "kbrandt")).is_true()
	await _seconds(1.0)
	# 2 m from the jack (horizontal): still plugged.
	_user.global_position = _n["Jack"].global_position + Vector3(0, -0.5, 2.0)
	await _seconds(0.1)
	assert_bool(_session.is_plugged()).is_true()
	assert_bool(_ice.is_running()).is_true()
	_user.global_position = _n["Jack"].global_position + Vector3(0, -0.5, 4.5)
	await _seconds(0.1)
	assert_bool(_session.is_plugged()).is_false()
	assert_str(String(_session.unplug_reason)).is_equal("walked_away")
	assert_bool(_ice.is_running()).is_false()
	# The progress stays on the deck's stack.
	var cracks := _stack.state[IcebreakerTool.CRACKS] as Dictionary
	assert_float(float((cracks.values()[0] as Dictionary)["progress"])).is_greater(0.05)


func test_a_maintenance_port_shows_its_device_only() -> void:
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_user.global_position = _n["Kiosk"].global_position + Vector3(0, -1, 1)
	assert_bool(_session.plug(_dev("Kiosk"), _stack)).is_true()
	await _seconds(0.3)
	assert_str(_session.source.address).is_equal("port:10.0.40.9")
	assert_array(_map()).is_equal(["Kiosk"])
	assert_bool(_session.is_online(_dev("Kiosk"))).is_true()
	assert_bool(_session.is_online(_dev("OfficePc"))).is_false()


func test_an_account_gives_the_devices_commands() -> void:
	await _plug_jack()
	DeviceAccounts.of(_n["Fw01"]).grant(_user, "admin")
	_session.refresh()
	await _seconds(0.3)
	var accounts := Net.add_accounts(_n["Camera"], [["maint", "cam", Net.WEAK]])
	assert_array(_session.commands_for(_dev("Camera"))).is_equal([Device.ENABLE, Device.DISABLE])
	assert_bool(_session.send(Device.DISABLE, _dev("Camera"))).is_false()
	accounts.grant(_user, "maint")
	assert_bool(_session.send(Device.DISABLE, _dev("Camera"))).is_true()
	await _seconds(0.05)
	assert_bool(DeviceSwitch.of(_n["Camera"]).disabled).is_true()
	var command := EventLog.find(&"device.command")[-1]
	assert_str(str(command.data["from"])).is_equal("Jack")
	assert_str(str(command.data["by"])).is_equal("Hacker")


func test_a_remote_desktop_returns_to_the_map_when_it_closes() -> void:
	await _plug_jack()
	assert_bool(_session.open_remote(_dev("OfficePc"))).is_false()
	DeviceAccounts.of(_n["OfficePc"]).grant(_user, "kbrandt")
	var changes: Array[Computer] = []
	_session.remote_changed.connect(func(computer: Computer) -> void: changes.append(computer))
	assert_bool(_session.open_remote(_dev("OfficePc"))).is_true()
	var computer := Computer.of(_n["OfficePc"])
	assert_object(_session.remote).is_same(computer)
	assert_str(str(EventLog.find(&"deck.remote")[0].data["user"])).is_equal("kbrandt")
	computer.desktop_closed.emit()
	assert_object(_session.remote).is_null()
	assert_array(changes).is_equal([computer, null])
