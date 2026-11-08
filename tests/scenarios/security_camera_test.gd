extends GdUnitTestSuite
## Scenario (EventLog, ADR 0079): the security camera in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout). The real player stands on
## the camera spot, 6 m in front of the lens on its rest axis, under a lamp: lit, it is detected in
## about 1 / (0.8 x 0.95) = 1.3 s; the camera's incident goes through the switch to the alarm
## controller, which rings the siren through the same switch. The turret is disabled in every test.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")

var _show: Showcase


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Turret")
	EventLog.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_a_lit_player_at_6_m_is_reported_once_and_the_siren_rings() -> void:
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	assert_float(LightExposure.of(_show.player).level).is_greater(0.5)
	var waited := await _show.wait_for(&"camera.detected", 4.0)
	# 1 / 0.76 = 1.3 s, give or take the light's first updates.
	assert_float(waited).is_between(0.9, 2.0)
	await _show.frames(12)

	var detected := EventLog.find(&"camera.detected")
	assert_array(detected).has_size(1)
	assert_str(String(detected[0].data["target"])).is_equal("Player")
	assert_int(int(detected[0].data["controllers"])).is_equal(1)
	var point: Vector3 = detected[0].data["point"]
	assert_float(point.distance_to(_show.player.global_position)).is_less(0.5)
	var chain: Array[EventLogEntry] = [
		detected[0],
		_first_emitted(&"device.incident"),
		EventLog.find(&"alarm.raised")[0],
		_first_emitted(&"command.ring"),
		EventLog.find(&"siren.started")[0],
	]
	for index in range(1, chain.size()):
		assert_int(chain[index].tick).override_failure_message(chain[index].kind).is_greater_equal(
			chain[index - 1].tick
		)
	assert_bool(_show.camera().meter.detected).is_true()
	# Still in view for 5 s more: no second incident.
	await _show.seconds(5.0)
	assert_array(EventLog.find(&"camera.detected")).has_size(1)
	assert_int(_count_emitted(&"device.incident")).is_equal(1)


func test_cloak_does_not_hide_the_player_from_a_camera() -> void:
	ActorState.set_tag(_show.player, ActorState.CLOAKED, true)
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	assert_float(await _show.wait_for(&"camera.detected", 4.0)).is_greater_equal(0.0)


func test_a_player_in_the_dark_is_never_seen() -> void:
	Powered.set_circuit(_show.scene.get_tree(), &"showcase_lights", false)
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	await _show.seconds(0.5)
	assert_float(LightExposure.of(_show.player).level).is_less(0.1)
	assert_float(await _show.wait_for(&"camera.detected", 6.0)).is_equal(-1.0)
	assert_float(_show.camera().meter.meter).is_equal(0.0)


func test_out_of_range_or_off_axis_nothing_is_seen() -> void:
	# 20 m from the lens on its axis (beyond 15 m): the sweep holds still for the test.
	await _show.command(Device.STOP_SWEEP, "Camera")
	await _show.place_player(Vector3(4, 0, 12.5), PI)
	await _show.seconds(3.0)
	assert_object(_show.camera().last_sighting).is_null()
	# 6 m away but 40 degrees off the axis (focus +-25): unseen while the camera holds at rest.
	var off_axis := Vector3(4, 0, -7.53) + Vector3(sin(deg_to_rad(40.0)), 0, cos(deg_to_rad(40.0))) * 6.0
	await _show.place_player(off_axis, PI)
	await _show.seconds(2.0)
	assert_array(EventLog.find(&"camera.detected")).is_empty()
	assert_float(_show.camera().meter.meter).is_equal(0.0)


func test_disabled_unpowered_or_broken_cameras_report_nothing() -> void:
	var cam := _show.camera()
	await _show.command(Device.DISABLE, "Camera")
	assert_bool(cam.is_watching()).is_false()
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"camera.detected")).is_empty()
	assert_bool((_show.node("Camera").get_node("Pivot/Tilt/Lamp") as Node3D).visible).is_false()

	await _show.command(Device.ENABLE, "Camera")
	Powered.of(_show.node("Camera")).on = false
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"camera.detected")).is_empty()

	Powered.of(_show.node("Camera")).on = true
	Breakable.of(_show.node("Camera")).take_damage(&"damage.ballistic", 25.0)
	assert_bool(ActorState.has(_show.node("Camera"), Device.BROKEN)).is_true()
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"camera.detected")).is_empty()
	assert_bool(cam.is_watching()).is_false()


func test_a_camera_cut_off_from_its_controller_still_detects_but_tells_nobody() -> void:
	Powered.of(_show.node("Switch")).on = false
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	assert_float(await _show.wait_for(&"camera.detected", 4.0)).is_greater_equal(0.0)
	await _show.frames(12)
	assert_int(int(EventLog.find(&"camera.detected")[0].data["controllers"])).is_equal(0)
	assert_array(EventLog.find(&"alarm.raised")).is_empty()


func test_pan_commands_turn_the_camera_away_from_the_player() -> void:
	# Pan steps are relative to where the sweep had it (a degree or two); three steps to its right
	# clamp at the 40 degree limit, so a player on its rest axis is 40 degrees off (focus +-25): unseen.
	for i in 3:
		await _show.command(Device.PAN_RIGHT, "Camera")
	assert_float(_show.camera().yaw()).is_equal(-40.0)
	assert_bool(_show.camera().model.sweeping).is_false()
	await _show.place_player(Showcase.CAMERA_SPOT, PI)
	await _show.seconds(2.5)
	assert_array(EventLog.find(&"camera.detected")).is_empty()
	var pivot := _show.node("Camera").get_node("Pivot") as Node3D
	assert_float(wrapf(rad_to_deg(pivot.rotation.y), -180.0, 180.0)).is_equal_approx(140.0, 0.5)
	# Three steps back to its left (5 degrees off the axis): seen.
	for i in 3:
		await _show.command(Device.PAN_LEFT, "Camera")
	assert_float(_show.camera().yaw()).is_equal(5.0)
	assert_float(await _show.wait_for(&"camera.detected", 4.0)).is_greater_equal(0.0)


func _first_emitted(type: StringName) -> EventLogEntry:
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data.get("type", &"") == type:
			return entry
	return null


func _count_emitted(type: StringName) -> int:
	var count := 0
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data.get("type", &"") == type:
			count += 1
	return count
