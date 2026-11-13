extends GdUnitTestSuite
## Integration (ADR 0099 amendment): the network map colours each node by the device's state as the
## map rows know it (network_map_checks.gd rows_from()), on a small network of stand-in devices
## built in code: a console cabled to switch A (powered) and switch B (unpowered). On A: an enabled device, a disabled
## one, a broken one and one that cannot be disabled; behind B: a disabled one and an enabled one.
## Offline (unreachable: unpowered, broken, cut off) is grey and beats disabled; disabled is red;
## otherwise green. Cables to a grey node are grey; a cable to a disabled node stays live. The three
## colours differ in brightness, not only hue.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const DisableStandIn := preload("res://tests/objects/devices/fixtures/disable_stand_in.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")

var _root: Node3D
var _graph: NetworkGraph
var _console: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	_root = Node3D.new()
	_root.position = Vector3(300, 0, -600)
	add_child(_root)
	var console := Devices.device(_root, "Console", Vector3(0, 0, 0))
	_console = console
	var switch_a := Devices.device(_root, "SwitchA", Vector3(-6, 0, 0), [], true)
	var switch_b := Devices.device(_root, "SwitchB", Vector3(6, 0, 0), [], true)
	Devices.link(console, switch_a)
	Devices.link(console, switch_b)
	_hang(switch_a, "Enabled", Vector3(-8, 0, -3), false)
	_hang(switch_a, "Disabled", Vector3(-8, 0, -1), true)
	var broken := _hang(switch_a, "Broken", Vector3(-8, 0, 1), false)
	var plain := Devices.device(_root, "Plain", Vector3(-8, 0, 3))
	Devices.link(switch_a, plain)
	_hang(switch_b, "Hidden", Vector3(8, 0, -2), true)
	_hang(switch_b, "Behind", Vector3(8, 0, 2), false)
	Powered.of(switch_b).on = false
	Device.of(broken).load_state({"broken": true})
	_graph = NetworkGraph.new()
	add_child(_graph)
	_graph.size = MapChecks.GRAPH_SIZE
	_graph.request_fit()
	var rows := MapChecks.rows_from(_console)
	_graph.show_network(rows, MapChecks.cables(rows), MapChecks.DECK_CONFIG.label_for)


func after_test() -> void:
	_graph.free()
	_root.free()


func test_each_node_takes_its_devices_colour() -> void:
	assert_array(_graph.node_names()).has_size(9)
	var expected := {
		"Enabled": DeckStyle.ONLINE_COLOR,
		"Plain": DeckStyle.ONLINE_COLOR,
		"Switch A": DeckStyle.ONLINE_COLOR,
		"Disabled": DeckStyle.DISABLED_COLOR,
		"Broken": DeckStyle.OFFLINE_COLOR,
		"Switch B": DeckStyle.OFFLINE_COLOR,
		"Behind": DeckStyle.OFFLINE_COLOR,
		# Disabled, but out of reach: the terminal cannot tell, so grey.
		"Hidden": DeckStyle.OFFLINE_COLOR,
	}
	for device_name: String in expected:
		var color: Color = expected[device_name]
		assert_object(_graph.node_color(device_name)).override_failure_message(device_name).is_equal(color)
		assert_object(_graph.node_status_color(device_name)).override_failure_message(device_name).is_equal(color)
	assert_str(_graph.node_status("Disabled")).is_equal("disabled")
	assert_str(_graph.node_status("Hidden")).is_equal("offline")
	assert_str(_graph.node_status("Broken")).is_equal("offline")
	# A disabled node's box is tinted too; a grey one (even disabled out of reach) is not.
	assert_object(_fill("Disabled")).is_equal(NetworkGraph.DISABLED_FILL)
	assert_object(_fill("Hidden")).is_equal(NetworkGraph.NODE_FILL)
	assert_object(_fill("Enabled")).is_equal(NetworkGraph.NODE_FILL)
	# The terminal keeps its own outline.
	assert_object(_graph.node_color("Console")).is_equal(DeckStyle.SELF_COLOR)


func test_the_menu_and_the_selection_stay_readable() -> void:
	_graph.select("Disabled")
	assert_object(_graph.menu_status.get_theme_color(&"font_color")).is_equal(DeckStyle.DISABLED_COLOR)
	# Selected: white outline whatever the colour, the status line keeps its colour.
	assert_object(_graph.node_color("Disabled")).is_equal(Color.WHITE)
	assert_object(_graph.node_status_color("Disabled")).is_equal(DeckStyle.DISABLED_COLOR)
	_graph.select("Behind")
	assert_object(_graph.menu_status.get_theme_color(&"font_color")).is_equal(DeckStyle.OFFLINE_COLOR)
	assert_object(_graph.node_color("Behind")).is_equal(Color.WHITE)
	assert_object(_graph.node_color("Disabled")).is_equal(DeckStyle.DISABLED_COLOR)
	_graph.close_menu()
	assert_object(_graph.node_color("Behind")).is_equal(DeckStyle.OFFLINE_COLOR)


func test_cables_to_grey_nodes_are_grey_and_a_disabled_end_stays_live() -> void:
	var names := _graph.cable_names()
	var live := {
		"Console-Switch A": true,
		"Switch A-Disabled": true,
		"Switch A-Enabled": true,
		"Console-Switch B": false,
		"Switch B-Hidden": false,
		"Switch A-Broken": false,
	}
	for cable: String in live:
		var k := names.find(cable)
		if k < 0:
			k = names.find(_reversed(cable))
		assert_int(k).override_failure_message("%s in %s" % [cable, names]).is_greater_equal(0)
		var expect_live: bool = live[cable]
		assert_bool(_graph.cable_live(k)).override_failure_message(cable).is_equal(expect_live)
		var color := NetworkGraph.LIVE_CABLE_COLOR if expect_live else DeckStyle.OFFLINE_COLOR
		assert_object(_graph.cable_color(k)).override_failure_message(cable).is_equal(color)


func test_the_colours_differ_in_brightness() -> void:
	# Relative luminance contrast between each pair, so the states stay apart without hue.
	var grey := _luminance(DeckStyle.OFFLINE_COLOR)
	var red := _luminance(DeckStyle.DISABLED_COLOR)
	var green := _luminance(DeckStyle.ONLINE_COLOR)
	assert_float((red + 0.05) / (grey + 0.05)).is_greater(1.8)
	assert_float((green + 0.05) / (red + 0.05)).is_greater(1.8)
	# Grey text stays readable on the map's background.
	assert_float((grey + 0.05) / (_luminance(NetworkGraph.BACKGROUND) + 0.05)).is_greater(2.5)


# Hangs a device with a DisableStandIn on `hub`.
func _hang(hub: Node3D, device_name: String, at: Vector3, disabled: bool) -> Node3D:
	var entity := Devices.device(_root, device_name, at, [], false, 10.0)
	var component: Node = DisableStandIn.new()
	component.set("disabled", disabled)
	entity.add_child(component)
	Devices.link(hub, entity)
	return entity


func _fill(device_name: String) -> Color:
	return (_graph.node_button(device_name).get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color


func _reversed(cable: String) -> String:
	var parts := cable.split("-")
	return "%s-%s" % [parts[1], parts[0]]


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
