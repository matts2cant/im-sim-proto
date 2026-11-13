extends GdUnitTestSuite
## Integration (ADR 0130): the Map's nodes in the device language, on two small networks of stand-in
## devices built in code (device_fixtures.gd) with no link between them, each node's kind given only
## by a tag. Network A (subnet "a"), seen from its jack:
##
##   JackA ── SwitchA ──┬── CamA (camera)
##                      ├── AlarmA (alarm, disabled by a command)
##                      ├── PlainA (no kind) ── SwitchC (unpowered switch) ── SirenA (siren)
##                      └── PcA (computer, unpowered) ── SwitchD (switch) ── CamD (camera)
##
## Network B (subnet "b"): JackB ── SwitchB ── CamB (camera, broken), LaserB (laser).
## A node shows its kind's colour on its strip and its icon in that colour (none without a kind);
## its status square takes the status light's colours: up green, cut off amber blinking (SirenA: its
## switch is down; CamD and SwitchD: up but the Map no longer reaches them, NetworkRow.light_of()),
## disabled or broken red, unpowered dark. Shown after A on the same graph, B's camera has its own
## state and nothing of A remains, and back on A nothing of B leaks.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const DisableStandIn := preload("res://tests/objects/devices/fixtures/disable_stand_in.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const ORIGIN := Vector3(-340, 0, 660)
const UP := StatusLight.State.UP
const CUT_OFF := StatusLight.State.CUT_OFF
const DISABLED := StatusLight.State.DISABLED
const DARK := StatusLight.State.DARK

var _root: Node3D
var _graph: NetworkGraph
var _n: Dictionary[String, Node3D] = {}
var _kinds: DeviceKinds = DeviceKinds.shipped()


func before_test() -> void:
	DebugPanel.set_open(false)
	_n.clear()
	_root = Node3D.new()
	_root.position = ORIGIN
	add_child(_root)
	_device("JackA", &"a", Vector3(0, 0, 0), [&"object.wall_jack"])
	_device("SwitchA", &"a", Vector3(2, 0, 0), [&"object.network_switch", DeviceNetwork.NETWORK_GEAR], true)
	_device("CamA", &"a", Vector3(4, 0, -2), [&"object.camera"])
	_device("AlarmA", &"a", Vector3(4, 0, 0), [&"object.alarm_controller"])
	var stand_in: Node = DisableStandIn.new()
	stand_in.set("disabled", true)
	_n["AlarmA"].add_child(stand_in)
	_device("PlainA", &"a", Vector3(4, 0, 2), [])
	_device("SwitchC", &"a", Vector3(2, 0, -4), [&"object.network_switch", DeviceNetwork.NETWORK_GEAR], true)
	_device("SirenA", &"a", Vector3(4, 0, -4), [&"object.siren"])
	_device("PcA", &"a", Vector3(2, 0, 4), [&"object.computer"], true)
	_device("SwitchD", &"a", Vector3(4, 0, 4), [&"object.network_switch", DeviceNetwork.NETWORK_GEAR])
	_device("CamD", &"a", Vector3(6, 0, 4), [&"object.camera"])
	for pair: Array in [
		["JackA", "SwitchA"],
		["SwitchA", "CamA"],
		["SwitchA", "AlarmA"],
		["SwitchA", "PlainA"],
		["PlainA", "SwitchC"],
		["SwitchC", "SirenA"],
		["SwitchA", "PcA"],
		["PcA", "SwitchD"],
		["SwitchD", "CamD"],
	]:
		Devices.link(_n[pair[0]], _n[pair[1]])
	Powered.of(_n["SwitchC"]).on = false
	Powered.of(_n["PcA"]).on = false
	_device("JackB", &"b", Vector3(-6, 0, 0), [&"object.wall_jack"])
	_device("SwitchB", &"b", Vector3(-8, 0, 0), [&"object.network_switch", DeviceNetwork.NETWORK_GEAR])
	_device("CamB", &"b", Vector3(-10, 0, -2), [&"object.camera"], false, 10.0)
	_device("LaserB", &"b", Vector3(-10, 0, 2), [&"object.laser"])
	for pair: Array in [["JackB", "SwitchB"], ["SwitchB", "CamB"], ["SwitchB", "LaserB"]]:
		Devices.link(_n[pair[0]], _n[pair[1]])
	Device.of(_n["CamB"]).load_state({"broken": true})
	_graph = NetworkGraph.new()
	add_child(_graph)
	_graph.size = MapChecks.DECK_MAP_SIZE


func after_test() -> void:
	_graph.free()
	_root.free()


# A stand-in device `entity_name` (shown under that name) on `subnet`, tagged `tags`.
func _device(
	entity_name: String,
	subnet: StringName,
	at: Vector3,
	tags: Array[StringName],
	powered: bool = false,
	health: float = 0.0,
) -> void:
	var entity := Devices.device(_root, entity_name, at, [], powered, health)
	for tag in tags:
		ActorState.set_tag(entity, tag, true)
	Device.of(entity).subnet = subnet
	entity.set_meta(&"display_name", entity_name)
	_n[entity_name] = entity


# Shows the network seen from `entry` on the graph.
func _show(entry: String) -> void:
	var rows := MapChecks.rows_from(_n[entry])
	_graph.show_network(rows, MapChecks.cables(rows), MapChecks.DECK_CONFIG.label_for)


func _box(device_name: String) -> NetworkNodeBox:
	return NetworkNodeBox.of(_graph.node_button(device_name))


func _light_of(device_name: String) -> Color:
	return NetworkNodeBox.fill_of(_box(device_name).light)


func _assert_lights(expected: Dictionary[String, StatusLight.State]) -> void:
	for device_name: String in expected:
		var box := _box(device_name)
		assert_object(box).override_failure_message(device_name).is_not_null()
		var state := expected[device_name]
		(
			assert_object(_light_of(device_name))
			. override_failure_message("%s: %s" % [device_name, StatusLight.State.keys()[state]])
			. is_equal(StatusLight.COLORS[state])
		)
		assert_bool(box.light_blinking).override_failure_message(device_name).is_equal(state == CUT_OFF)


func test_each_node_shows_its_kinds_colour_on_its_strip_and_icon() -> void:
	_show("JackA")
	assert_array(_graph.node_names()).has_size(10)
	var with_kind := 0
	for row in _graph.rows:
		var box := _box(row.name)
		var kind := _kinds.kind_for(row.device.entity)
		if kind == null:
			assert_object(box.strip).override_failure_message(row.name).is_null()
			assert_object(box.icon).override_failure_message(row.name).is_null()
			continue
		with_kind += 1
		assert_object(NetworkNodeBox.fill_of(box.strip)).override_failure_message(row.name).is_equal(kind.color)
		assert_object(box.icon.colour).override_failure_message(row.name).is_equal(kind.color)
		assert_array(Array(box.icon.strokes)).override_failure_message(row.name).is_equal(Array(kind.icon))
	assert_int(with_kind).is_equal(9)
	# Kinds by tag only: both cameras yellow, the switches blue, the siren and alarm red.
	var camera := _kinds.kind_with_tag(&"object.camera").color
	assert_object(NetworkNodeBox.fill_of(_box("CamD").strip)).is_equal(camera)
	assert_object(_box("PlainA").light).is_not_null()
	# Selected, disabled or offline: the outline changes, the strip and icon keep the kind's colour.
	_graph.select("AlarmA")
	var alarm := _kinds.kind_with_tag(&"object.alarm_controller").color
	assert_object(_graph.node_color("AlarmA")).is_equal(Color.WHITE)
	assert_object(_box("AlarmA").icon.colour).is_equal(alarm)
	assert_object(_graph.node_color("SirenA")).is_equal(DeckStyle.OFFLINE_COLOR)
	assert_object(_box("SirenA").icon.colour).is_equal(_kinds.kind_with_tag(&"object.siren").color)


func test_the_status_square_follows_the_device_state() -> void:
	_show("JackA")
	_assert_lights(
		{
			"JackA": UP,
			"SwitchA": UP,
			"CamA": UP,
			"PlainA": UP,
			"AlarmA": DISABLED,
			"SwitchC": DARK,
			"PcA": DARK,
			"SirenA": CUT_OFF,
			"SwitchD": CUT_OFF,
			"CamD": CUT_OFF,
		}
	)
	# The Map's own words agree: disabled red, unreachable grey.
	assert_str(_graph.node_status("AlarmA")).is_equal("disabled")
	assert_str(_graph.node_status("CamD")).is_equal("offline")
	# The power comes back: the computer and what hangs behind it are up and reached again.
	Powered.of(_n["PcA"]).on = true
	Powered.of(_n["SwitchC"]).on = true
	_show("JackA")
	_assert_lights({"PcA": UP, "SwitchD": UP, "CamD": UP, "SwitchC": UP, "SirenA": UP, "AlarmA": DISABLED})


func test_a_second_unconnected_network_keeps_its_own_kinds_and_states() -> void:
	_show("JackA")
	_show("JackB")
	assert_array(_graph.node_names()).contains_exactly_in_any_order(["JackB", "SwitchB", "CamB", "LaserB"])
	var camera := _kinds.kind_with_tag(&"object.camera").color
	assert_object(NetworkNodeBox.fill_of(_box("CamB").strip)).is_equal(camera)
	assert_object(NetworkNodeBox.fill_of(_box("LaserB").strip)).is_equal(_kinds.kind_with_tag(&"object.laser").color)
	_assert_lights({"JackB": UP, "SwitchB": UP, "LaserB": UP, "CamB": DISABLED})
	assert_str(_graph.node_status("CamB")).is_equal("offline")
	# Back on A: its camera is green again, nothing of B shows.
	_show("JackA")
	assert_bool(_graph.node_names().has("CamB")).is_false()
	_assert_lights({"CamA": UP, "CamD": CUT_OFF})


func test_a_cut_off_square_blinks_and_a_dark_one_is_outlined() -> void:
	_show("JackA")
	var square := _box("SirenA").light
	assert_float(square.modulate.a).is_equal(1.0)
	assert_bool(await _alpha_becomes(square, NetworkNodeBox.BLINK_DIM)).is_true()
	assert_bool(await _alpha_becomes(square, 1.0)).is_true()
	assert_bool(await _alpha_becomes(square, NetworkNodeBox.BLINK_DIM)).is_true()
	# A steady square never changes.
	assert_object(_box("CamA").light.get_node_or_null(^"Blink")).is_null()
	var dark := _box("PcA").light.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_int(dark.border_width_left).is_equal(1)
	assert_object(dark.border_color).is_equal(NetworkNodeBox.DARK_EDGE)


# Waits until `square`'s alpha is `alpha` (at most 300 process frames: several blink halves of
# simulated time).
func _alpha_becomes(square: Control, alpha: float) -> bool:
	for i in 300:
		if is_equal_approx(square.modulate.a, alpha):
			return true
		await get_tree().process_frame
	return is_equal_approx(square.modulate.a, alpha)
