extends GdUnitTestSuite
## Integration (M12b, ADR 0115, 0117): the deck's WirelessTool and DeckSession on a minimal user
## entity (network_fixtures.gd user(): its origin is its eye) aimed at the access point AP-YARD of
## the lab network (add_wireless()). The deck's Wi-Fi range per Computer skill tier (8 / 12 / 18 /
## 25 m, straight line); the Icebreaker cracks the key while the access point is in range and in
## sight: a wall between them pauses it and it goes on once the wall is gone, leaving the range
## pauses it too; it adds trace on the tracer watching the access point's subnet; a cracked key joins
## the deck to the security subnet over Wi-Fi (its map and reach from there) and leaving the range
## drops it and stops its tools; the progress is kept on the deck (saved) and resumed.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(420, 0, -380)
## AP-YARD's position in the lab (network_fixtures.gd add_wireless()).
const AP := Vector3(12, 2.6, 3)
## The user's eye 6 m north of the access point (in range at every tier).
const NEAR := Vector3(12, 2.6, -3)
## The deck's Wi-Fi range per tier (m).
const RANGES: Array[float] = [8.0, 12.0, 18.0, 25.0]

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession
var _wireless: WirelessTool
var _ice: IcebreakerTool
var _stack: ItemStack


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	Net.add_wireless(_n, _root, ORIGIN)
	_user = Net.user(_root, ORIGIN + NEAR)
	_session = DeckSession.of(_user)
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_wireless = WirelessTool.of(_user)
	_ice = IcebreakerTool.of(_user)
	_stack = Net.deck_stack()
	await _frames(2)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	StimulusSystem.clear()


func _ap() -> Device:
	return Device.of(_n["ApYard"])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * 60.0))


func _tracer() -> Tracer:
	return _n["Rtr01"].get_node("Tracer") as Tracer


# A wall of world geometry across the line from NEAR to the access point.
func _wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.global_position = ORIGIN + Vector3(12, 1.5, 0)
	return wall


func test_the_decks_wifi_range_grows_with_the_computer_skill() -> void:
	for tier in RANGES.size():
		Net.set_tier(_user, tier)
		assert_float(_wireless.wireless_range()).is_equal_approx(RANGES[tier], 0.001)
		# 1 m inside and 1 m outside the range (straight line, the eye to the access point).
		_user.global_position = ORIGIN + AP + Vector3(RANGES[tier] - 1.0, 0, 0)
		assert_bool(_wireless.in_range(_ap())).override_failure_message("tier %d inside" % tier).is_true()
		_user.global_position = ORIGIN + AP + Vector3(RANGES[tier] + 1.0, 0, 0)
		assert_bool(_wireless.in_range(_ap())).override_failure_message("tier %d outside" % tier).is_false()
	# Aiming from out of range only says so; from in range it is the target.
	Net.set_tier(_user, 0)
	var notices: Array[String] = []
	_session.notice.connect(func(text: String) -> void: notices.append(text))
	assert_bool(_wireless.aim(_ap(), _stack)).is_false()
	assert_object(_wireless.target).is_null()
	assert_str(notices[0]).contains("out of the deck's Wi-Fi range")
	_user.global_position = ORIGIN + NEAR
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_object(_wireless.target).is_same(_ap())


func test_a_cracked_key_joins_the_subnet_and_leaving_the_range_drops_it() -> void:
	Net.set_tier(_user, 1)
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_wireless.start()).is_true()
	await _seconds(1.0)
	# Trained: a Weak key in 7.5 s; 1 s in, about 13 %, and trace on the tracer watching security.
	assert_float(_wireless.job.progress).is_between(0.1, 0.17)
	assert_float(_tracer().trace_of(_user)).is_greater(2.0)
	_wireless.job.progress = 0.95
	await _seconds(1.0)
	assert_bool(AccessPoint.of(_n["ApYard"]).knows_key(_user)).is_true()
	assert_int(EventLog.find(&"deck.wifi_cracked").size()).is_equal(1)
	# Joined over Wi-Fi: an address on the security subnet, the access point as the entry point.
	assert_bool(_session.is_wireless()).is_true()
	assert_object(_session.port).is_same(_ap())
	assert_str(_session.source.address).is_equal("10.0.20.90")
	assert_str(String(_session.source.subnet)).is_equal("security")
	await _seconds(0.3)
	var shown: Array[String] = []
	for device in _session.map_devices():
		shown.append(String(device.entity.name))
	assert_array(shown).contains(["ApYard", "CamYard", "LaserRoof", "Console", "Camera", "Rtr01", "Rtr02"])
	assert_bool(shown.has("OfficePc")).is_false()
	assert_bool(_session.is_online(Device.of(_n["CamYard"]))).is_true()
	# The tools work from there: the Icebreaker on the console runs.
	assert_bool(_ice.start(Device.of(_n["Console"]), "dmarsh")).is_true()
	await _seconds(0.2)
	assert_bool(_ice.is_running()).is_true()
	# Out of the Trained range (12 m): the Wi-Fi drops and its tools stop.
	_user.global_position = ORIGIN + AP + Vector3(0, 0, -14)
	await _frames(2)
	assert_bool(_session.is_plugged()).is_false()
	assert_str(String(_session.unplug_reason)).is_equal("out_of_range")
	assert_bool(_ice.is_running()).is_false()
	# Back in range, aiming at it joins again at once (the key is known).
	_user.global_position = ORIGIN + NEAR
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_session.is_wireless()).is_true()


func test_a_wall_in_the_line_of_sight_pauses_the_crack_until_it_is_gone() -> void:
	assert_bool(_wireless.has_sight(_ap())).is_true()
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_wireless.start()).is_true()
	await _seconds(0.5)
	var before := _wireless.job.progress
	assert_float(before).is_greater(0.02)
	var wall := _wall()
	await _frames(3)
	assert_bool(_wireless.has_sight(_ap())).is_false()
	var paused := _wireless.job.progress
	await _seconds(1.0)
	# Paused, not stopped: still running, no progress, the reason said.
	assert_bool(_wireless.is_running()).is_true()
	assert_float(_wireless.job.progress).is_equal_approx(paused, 0.0001)
	assert_str(String(_wireless.pause_reason())).is_equal(String(WirelessTool.NO_SIGHT))
	var pauses := EventLog.find(&"deck.wifi").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["action"] == &"pause"
	)
	assert_int(pauses.size()).is_equal(1)
	# The wall gone: it goes on by itself.
	wall.free()
	await _seconds(0.5)
	assert_str(String(_wireless.pause_reason())).is_empty()
	assert_float(_wireless.job.progress).is_greater(paused + 0.02)


func test_out_of_range_pauses_the_crack_and_back_in_range_it_goes_on() -> void:
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_wireless.start()).is_true()
	await _seconds(0.5)
	# Untrained: 8 m; 10 m north of the access point.
	_user.global_position = ORIGIN + AP + Vector3(0, 0, -10)
	await _frames(2)
	var paused := _wireless.job.progress
	await _seconds(0.5)
	assert_str(String(_wireless.pause_reason())).is_equal(String(WirelessTool.OUT_OF_RANGE))
	assert_float(_wireless.job.progress).is_equal_approx(paused, 0.0001)
	_user.global_position = ORIGIN + NEAR
	await _seconds(0.5)
	assert_float(_wireless.job.progress).is_greater(paused + 0.02)


func test_the_progress_is_kept_on_the_deck_and_resumed() -> void:
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_wireless.start()).is_true()
	await _seconds(2.0)
	_wireless.stop()
	var kept := _wireless.saved_progress(_ap())
	# Untrained, a Weak key in 10 s: about 20 % after 2 s.
	assert_float(kept).is_between(0.15, 0.25)
	# What a save writes (JSON), loaded into another deck stack; aimed and started again, it resumes.
	var state: Variant = JSON.from_native(_stack.state)
	var loaded := ItemStack.new(_stack.item, 1, JSON.to_native(state) as Dictionary)
	_wireless.target = null
	assert_bool(_wireless.aim(_ap(), loaded)).is_true()
	assert_float(_wireless.saved_progress(_ap())).is_equal_approx(kept, 0.0001)
	assert_bool(_wireless.start()).is_true()
	assert_float(_wireless.job.progress).is_equal_approx(kept, 0.0001)
	# A changed key starts over.
	_wireless.stop()
	AccessPoint.of(_n["ApYard"]).key = "changed99"
	assert_float(_wireless.saved_progress(_ap())).is_equal(0.0)


func test_a_key_too_strong_for_the_skill_cannot_be_cracked() -> void:
	AccessPoint.of(_n["ApYard"]).key_strength = DeviceAccount.Strength.MEDIUM
	assert_bool(_wireless.aim(_ap(), _stack)).is_true()
	assert_bool(_wireless.can_crack(_ap())).is_false()
	assert_bool(_wireless.start()).is_false()
	Net.set_tier(_user, 1)
	assert_bool(_wireless.start()).is_true()
	# Trained, Medium: 24 s x 0.75 = 18 s.
	assert_float(_wireless.crack_time(_ap())).is_equal_approx(18.0, 0.001)
