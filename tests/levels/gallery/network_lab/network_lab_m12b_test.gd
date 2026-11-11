extends GdUnitTestSuite
## Network lab (gallery room 8), the M12b annex stations with the real Player in the room fixture
## (fixtures/lab_player.tscn; design/levels/hub-and-gallery.md "M12b annex"):
## - Wi-Fi: from the 6 m mark, Untrained, LMB on AP-LAB raises the Wi-Fi key screen and the crack
##   runs; behind the pillar it pauses ("line of sight lost"); from the 10 m mark AP-LAB is out of
##   the Untrained range and in the Trained one; with the key known, aiming joins the Wi-Fi subnet and
##   the Map shows the access point, its wireless camera and laser, SW-WIFI and RTR-03.
## - Exploits: the datapad teaches two exploits; on the CCTV jack the Helix one matches CAM-EX1 and
##   CAM-EX2, not CAM-EX3 (2.4), the EdgeGuard one RTR-03; a run on CAM-EX1 grants admin and, seen
##   by the Watchdog tracer, patches CAM-EX2 (and not the Wi-Fi camera on its unwatched subnet).
## - Firewall: the note's login logs in on RTR-04 from the alarm jack's Map (the Sirens subnet
##   appears); a DENY rule from the alarm controller to the Sirens subnet keeps them silent when the
##   panic button is pressed.
## Lab-local positions.

const Helpers := preload("res://tests/levels/gallery/network_lab/network_lab_helpers.gd")
const SPOT_6 := Vector3(15.6, 0, -25.5)
const SPOT_10 := Vector3(11.6, 0, -25.5)
const BEHIND_PILLAR := Vector3(16.0, 0, -27.9)
const AT_CCTV_JACK := Vector3(11.6, 0, -31.6)
const AT_ALARM_JACK := Vector3(8.65, 0, -22.0)
const AT_PANIC := Vector3(8.65, 0, -25.4)

var _lab: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_lab = Helpers.new()
	await _lab.setup(scene_runner(Helpers.FIXTURE))


func after_test() -> void:
	var session := DeckSession.of(_lab.player)
	if session != null:
		session.unplug()
	var screen := DeckScreen.of(_lab.player)
	if screen != null and screen.is_open():
		screen.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


# Takes the deck with fast scans and exploit runs (the shipped times are covered by the deck's tests).
func _take_fast_deck() -> DeckSession:
	assert_bool(await _lab.take_deck()).is_true()
	var session := DeckSession.of(_lab.player)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	session.config.exploit_time = 1.0
	return session


func test_the_wifi_crack_runs_from_6_m_pauses_behind_the_pillar_and_10_m_needs_trained() -> void:
	await _take_fast_deck()
	var ap := _lab.device("Devices/ApLab")
	var wireless := WirelessTool.of(_lab.player)
	await _lab.click(SPOT_6, "Devices/ApLab")
	assert_object(wireless.target).is_same(ap)
	assert_bool(DeckScreen.of(_lab.player).is_open()).is_true()
	assert_bool(wireless.start()).is_true()
	await _lab.seconds(1.0)
	assert_str(String(wireless.pause_reason())).is_empty()
	var progress := wireless.job.progress
	assert_float(progress).is_greater(0.05)
	# Behind the pillar: paused, line of sight lost, still in range.
	await _lab.stand(BEHIND_PILLAR, _lab.node("Devices/ApLab").position)
	await _lab.seconds(0.5)
	assert_str(String(wireless.pause_reason())).is_equal(String(WirelessTool.NO_SIGHT))
	assert_str(WifiPanel.pause_text(wireless.pause_reason())).is_equal("line of sight lost")
	assert_bool(wireless.in_range(ap)).is_true()
	var paused_at := wireless.job.progress
	await _lab.seconds(0.5)
	assert_float(wireless.job.progress).is_equal_approx(paused_at, 0.0001)
	wireless.stop()
	DeckScreen.of(_lab.player).close()
	# The 10 m mark: out of the Untrained range, in the Trained one.
	await _lab.stand(SPOT_10, _lab.node("Devices/ApLab").position)
	assert_bool(wireless.in_range(ap)).is_false()
	assert_bool(wireless.has_sight(ap)).is_true()
	_lab.player.skills.set_tier(&"computer", 1)
	await _lab.seconds(0.1)
	assert_bool(wireless.in_range(ap)).is_true()
	# With the key known, aiming joins the Wi-Fi subnet and the Map shows its side of RTR-03.
	AccessPoint.of(ap).grant_key(_lab.player)
	await _lab.click(SPOT_10, "Devices/ApLab")
	var session := DeckSession.of(_lab.player)
	assert_bool(session.is_wireless()).is_true()
	assert_str(session.source.address).is_equal("10.0.40.200")
	await _lab.seconds(0.3)
	var screen := DeckScreen.of(_lab.player)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains_exactly_in_any_order(
		["AP-LAB", "CAM-WIFI", "LASER-WIFI", "SW-WIFI", "RTR-03"]
	)


func test_an_exploit_run_on_cctv_is_seen_and_patches_the_other_camera() -> void:
	var session := await _take_fast_deck()
	await _lab.stand(Vector3(10, 0, -31.0), _lab.node("Items/ExploitNotes").position)
	await _lab.read("Items/ExploitNotes")
	await _lab.click(AT_CCTV_JACK, "Devices/CctvJack")
	assert_object(session.port).is_same(_lab.device("Devices/CctvJack"))
	await _lab.seconds(0.3)
	var tool := ExploitTool.of(_lab.player)
	assert_int(tool.known().size()).is_equal(2)
	var helix := tool.matching(_lab.device("Devices/CamEx1"))
	assert_int(helix.size()).is_equal(1)
	assert_str(helix[0].product).is_equal("CAM-3")
	assert_int(tool.matching(_lab.device("Devices/CamEx2")).size()).is_equal(1)
	assert_array(tool.matching(_lab.device("Devices/CamEx3"))).is_empty()
	assert_str(tool.matching(_lab.device("Devices/Rtr03"))[0].product).is_equal("EdgeGuard")
	# The run on CAM-EX1 (1 s here): admin there; the Watchdog saw it, so CAM-EX2 is patched.
	tool.select(_lab.device("Devices/CamEx1"))
	assert_bool(tool.start(helix[0])).is_true()
	await _lab.seconds(1.3)
	assert_bool(_lab.device("Devices/CamEx1").is_admin(_lab.player)).is_true()
	var watchdog := _lab.node("Devices/Rtr03").get_node("Tracer") as Tracer
	assert_float(watchdog.trace_of(_lab.player)).is_greater(0.0)
	assert_bool(_lab.device("Devices/CamEx2").intrusion.is_patched(helix[0])).is_true()
	assert_bool(tool.can_run(_lab.device("Devices/CamEx2"), helix[0])).is_false()
	assert_bool(_lab.device("Devices/WifiCamera").intrusion.is_patched(helix[0])).is_false()


func test_the_note_logs_in_on_rtr04_and_a_deny_rule_keeps_the_sirens_silent() -> void:
	var session := await _take_fast_deck()
	await _lab.stand(Vector3(8.9, 0, -21.3), _lab.node("Items/Rtr04Note").position)
	await _lab.read("Items/Rtr04Note")
	await _lab.click(AT_ALARM_JACK, "Devices/AlarmJack")
	await _lab.seconds(0.3)
	var screen := DeckScreen.of(_lab.player)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains_exactly_in_any_order(
		["ALARM-JACK", "SW-ALARM", "ALARM-LAB", "PANIC-LAB", "RTR-04"]
	)
	# The Map logs in with the note's login: the Sirens subnet appears and RTR-04 is ours.
	assert_bool(screen.graph.select("RTR-04")).is_true()
	var log_in := ""
	for text in screen.menu_texts():
		if text.begins_with("Log in (from"):
			log_in = text
	assert_str(log_in).is_not_empty()
	screen.menu_button(log_in).pressed.emit()
	await _lab.seconds(0.3)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains(["SW-SIRENS", "SIREN-A", "SIREN-B"])
	var router := Router.of(_lab.node("Devices/Rtr04"))
	assert_bool(_lab.device("Devices/Rtr04").is_admin(_lab.player)).is_true()
	# ALARM-LAB -> SIRENS: DENY, added as the Firewall tool does (from the deck).
	router.add_rule(
		RouterRule.make(RouterRule.Match.DEVICE, "AlarmController", RouterRule.Match.SUBNET, "lab_sirens", false),
		-1,
		session.source
	)
	session.unplug()
	await _lab.stand(AT_PANIC, _lab.node("Devices/PanicButton").position)
	var panic := _lab.node("Devices/PanicButton").find_children("*", "PanicButton", false, false)[0] as PanicButton
	assert_bool(panic.use(_lab.player)).is_true()
	await _lab.seconds(1.0)
	var controller := (
		_lab.node("Devices/AlarmController").find_children("*", "AlarmController", false, false)[0] as AlarmController
	)
	assert_bool(controller.is_ringing()).is_true()
	for path: String in ["Devices/SirenA", "Devices/SirenB"]:
		var siren := _lab.node(path).find_children("*", "Siren", false, false)[0] as Siren
		assert_bool(siren.is_sounding()).override_failure_message(path).is_false()
