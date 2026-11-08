extends GdUnitTestSuite
## Integration (ADR 0083): the Overlays tab's Network checkbox and the NetworkOverlay it drives, on
## minimal device entities (tests/objects/devices/device_fixtures.gd): a label per device with its
## name and DeviceStatus words (a stand-in component adds its own), a line per cable, up while both
## ends are up; cutting the switch turns its cables down; off, nothing is shown or drawn.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const StatusStandIn := preload("res://tests/objects/devices/fixtures/status_stand_in.gd")

var _overlay: NetworkOverlay
var _root: Node3D


func before_test() -> void:
	StimulusSystem.clear()
	_overlay = DebugPanel.network_overlay
	_set_checkbox(false)
	_root = auto_free(Node3D.new())
	_root.position = Vector3(0, 0, 400)
	add_child(_root)


func after_test() -> void:
	_set_checkbox(false)


func test_labels_and_cables_follow_the_devices() -> void:
	var hub := Devices.device(_root, "HubSwitch", Vector3(0, 1, 0), [], true)
	var bell := Devices.device(_root, "Bell", Vector3(3, 1, 0))
	var sensor := Devices.device(_root, "Sensor", Vector3(0, 1, 3))
	var words: Node = StatusStandIn.new()
	words.set("words", PackedStringArray(["ringing"]))
	bell.add_child(words)
	Devices.link(hub, bell)
	Devices.link(sensor, hub)
	# Listed on one end only, a cable is drawn once even when both ends list it.
	Devices.link(bell, hub)
	await get_tree().process_frame

	_set_checkbox(true)
	assert_bool(_overlay.enabled).is_true()
	assert_bool(_overlay.is_processing()).is_true()
	assert_str(_overlay.label_for(Device.of(bell)).text).is_equal("Bell\nonline · ringing")
	assert_str(_overlay.label_for(Device.of(hub)).text).is_equal("Hub Switch\nonline")
	var label := _overlay.label_for(Device.of(sensor))
	assert_vector(label.global_position).is_equal_approx(
		sensor.global_position + Vector3(0, 0.45, 0), Vector3.ONE * 0.001
	)
	assert_bool(label.no_depth_test).is_true()
	assert_int(_overlay.cable_state(Device.of(hub), Device.of(bell))).is_equal(1)
	assert_int(_overlay.cable_state(Device.of(sensor), Device.of(hub))).is_equal(1)
	assert_int(_overlay.cable_state(Device.of(sensor), Device.of(bell))).is_equal(-1)
	assert_int(_cables_between([hub, bell, sensor])).is_equal(2)

	# The switch unpowered: its cables go down and its label says why (a developer view).
	Powered.of(hub).on = false
	_overlay.refresh()
	assert_int(_overlay.cable_state(Device.of(hub), Device.of(bell))).is_equal(0)
	assert_int(_overlay.cable_state(Device.of(sensor), Device.of(hub))).is_equal(0)
	assert_str(_overlay.label_for(Device.of(hub)).text).is_equal("Hub Switch\noffline (unpowered)")
	assert_str(_overlay.label_for(Device.of(bell)).text).is_equal("Bell\nonline · ringing")

	# Off: no labels, no lines, no processing.
	_set_checkbox(false)
	assert_int(_overlay.label_count()).is_equal(0)
	assert_int(_overlay.cable_count()).is_equal(0)
	assert_int(_overlay.vertex_count()).is_equal(0)
	assert_bool(_overlay.is_processing()).is_false()


func test_refreshes_on_its_own_while_on() -> void:
	var hub := Devices.device(_root, "HubSwitch", Vector3(0, 1, 0), [], true)
	var bell := Devices.device(_root, "Bell", Vector3(3, 1, 0))
	Devices.link(hub, bell)
	await get_tree().process_frame
	_set_checkbox(true)
	assert_int(_overlay.cable_state(Device.of(hub), Device.of(bell))).is_equal(1)
	Powered.of(hub).on = false
	for i in 30:
		await get_tree().process_frame
	assert_int(_overlay.cable_state(Device.of(hub), Device.of(bell))).is_equal(0)
	# A device that leaves the level loses its label.
	var before := _overlay.label_count()
	bell.free()
	_overlay.refresh()
	assert_int(_overlay.label_count()).is_equal(before - 1)
	assert_int(_overlay.cable_state(Device.of(hub), null)).is_equal(-1)


# Cables drawn between the given entities' devices (other suites' leftovers may add more).
func _cables_between(entities: Array[Node3D]) -> int:
	var count := 0
	for i in entities.size():
		for j in range(i + 1, entities.size()):
			if _overlay.cable_state(Device.of(entities[i]), Device.of(entities[j])) >= 0:
				count += 1
	return count


func _overlays_tab() -> OverlaysTab:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Overlays":
			return tabs.get_tab_control(i) as OverlaysTab
	return null


func _set_checkbox(pressed: bool) -> void:
	var checkbox: CheckBox = _overlays_tab().get_node("Network")
	checkbox.button_pressed = pressed
