extends GdUnitTestSuite
## Integration (M12c readability, ADR 0122): StatusLight and GearPlate on minimal entities built from
## components (network_fixtures.body_device), not shipped scenes: any Device on a network gets an LED
## (green up, amber cut off, red disabled or broken but powered, dark unpowered), network gear (the
## NETWORK_GEAR tag) port lights that follow the far ends and a plate generated from its links.
##   Core (gear) ── Switch (gear) ── Camera (DeviceSwitch), Panel, Printer
##   Lone: no cables (no light)

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const ORIGIN := Vector3(520, 0, -520)

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_n.clear()
	_n["Core"] = _gear("Core", Vector3(0, 1.5, 0))
	_n["Switch"] = _gear("Switch", Vector3(2, 1.5, 0))
	var receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.ENABLE)
	]
	_n["Camera"] = Net.body_device(_root, "Camera", ORIGIN + Vector3(2, 2.5, 2), receptrons, true, 10.0)
	var toggle := DeviceSwitch.new()
	toggle.name = "DeviceSwitch"
	_n["Camera"].add_child(toggle)
	_n["Panel"] = Net.body_device(_root, "Panel", ORIGIN + Vector3(3, 1, 2), [], true, 10.0)
	_n["Printer"] = Net.body_device(_root, "Printer", ORIGIN + Vector3(4, 1, 2))
	_n["Lone"] = Net.body_device(_root, "Lone", ORIGIN + Vector3(6, 1, 2))
	Net.link(_n["Switch"], _n["Core"])
	for leaf: String in ["Camera", "Panel", "Printer"]:
		Net.link(_n[leaf], _n["Switch"])
	for entity_name: String in _n:
		_n[entity_name].set_meta(&"display_name", entity_name.to_upper())
	# The lights attach deferred, once the cables are in.
	await get_tree().process_frame


func after_test() -> void:
	StimulusSystem.clear()


func _gear(entity_name: String, at: Vector3) -> Node3D:
	var entity := Net.body_device(_root, entity_name, ORIGIN + at, [], true, 10.0)
	ActorState.set_tag(entity, DeviceNetwork.NETWORK_GEAR, true)
	return entity


func _light(entity_name: String) -> StatusLight:
	return StatusLight.of(_n[entity_name])


func _power(entity_name: String, on: bool) -> void:
	(_n[entity_name].get_node("Powered") as Powered).on = on


func _break(entity_name: String) -> void:
	Breakable.of(_n[entity_name]).take_damage(&"ballistic", 100.0)


func test_networked_devices_get_a_light_and_standalone_ones_none() -> void:
	for entity_name: String in ["Core", "Switch", "Camera", "Panel", "Printer"]:
		assert_object(_light(entity_name)).override_failure_message(entity_name).is_not_null()
	assert_object(_light("Lone")).is_null()
	assert_int(_light("Switch").port_lights.size()).is_equal(4)
	assert_object(_light("Camera").led).is_not_null()
	assert_array(_light("Camera").port_lights).is_empty()


func test_up_devices_are_green_and_ports_lit() -> void:
	for entity_name: String in ["Core", "Switch", "Camera", "Panel", "Printer"]:
		assert_int(_light(entity_name).state).override_failure_message(entity_name).is_equal(StatusLight.State.UP)
	assert_array(_light("Switch").port_states()).is_equal([true, true, true, true])


func test_a_cut_switch_leaves_its_devices_amber_and_its_ports_dark() -> void:
	_power("Switch", false)
	assert_int(_light("Switch").state).is_equal(StatusLight.State.DARK)
	assert_int(_light("Camera").state).is_equal(StatusLight.State.CUT_OFF)
	assert_int(_light("Panel").state).is_equal(StatusLight.State.CUT_OFF)
	assert_array(_light("Switch").port_states()).is_equal([false, false, false, false])
	# The core keeps nothing else up but is still on: linked only to gear, all down.
	assert_int(_light("Core").state).is_equal(StatusLight.State.CUT_OFF)
	_power("Switch", true)
	assert_int(_light("Camera").state).is_equal(StatusLight.State.UP)


func test_port_lights_follow_the_far_end() -> void:
	_power("Panel", false)
	assert_int(_light("Panel").state).is_equal(StatusLight.State.DARK)
	var lit := _light("Switch").port_states()
	var ports := _light("Switch").ports
	assert_bool(lit[ports.find(Device.of(_n["Panel"]))]).is_false()
	assert_bool(lit[ports.find(Device.of(_n["Camera"]))]).is_true()
	assert_bool(lit[ports.find(Device.of(_n["Core"]))]).is_true()


func test_disabled_and_broken_are_red_unpowered_is_dark() -> void:
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _n["Camera"]))
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_int(_light("Camera").state).is_equal(StatusLight.State.DISABLED)
	_break("Panel")
	assert_int(_light("Panel").state).is_equal(StatusLight.State.DISABLED)
	assert_bool(_light("Switch").port_states()[_light("Switch").ports.find(Device.of(_n["Panel"]))]).is_false()
	_power("Panel", false)
	assert_int(_light("Panel").state).is_equal(StatusLight.State.DARK)
	# Broken while unpowered, then powered again: red, not green.
	_power("Panel", true)
	assert_int(_light("Panel").state).is_equal(StatusLight.State.DISABLED)


func test_eight_ports_then_a_plus() -> void:
	var eight := _gear("Eight", Vector3(0, 1.5, 6))
	var nine := _gear("Nine", Vector3(0, 1.5, 9))
	for i in 8:
		Net.link(Net.body_device(_root, "LeafA%d" % i, ORIGIN + Vector3(i, 1, 7)), eight)
	for i in 9:
		Net.link(Net.body_device(_root, "LeafB%d" % i, ORIGIN + Vector3(i, 1, 10)), nine)
	await get_tree().process_frame
	assert_int(StatusLight.of(eight).port_lights.size()).is_equal(8)
	assert_object(StatusLight.of(eight).more).is_null()
	var light := StatusLight.of(nine)
	assert_int(light.port_lights.size()).is_equal(StatusLight.MAX_PORTS)
	assert_object(light.more).is_not_null()
	assert_str(light.more.text).is_equal("+")


func test_plate_names_the_gear_and_what_it_feeds() -> void:
	var plate := _n["Switch"].get_node("GearPlate") as GearPlate
	assert_object(plate).is_not_null()
	assert_object(_n["Camera"].get_node_or_null("GearPlate")).is_null()
	assert_str(GearPlate.plate_text(Device.of(_n["Switch"]))).is_equal("SWITCH · feeds CORE, CAMERA, PANEL, PRINTER")
	assert_str(plate.text).is_equal("SWITCH\nfeeds CORE, CAMERA, PANEL, PRINTER")


func test_a_router_uplink_is_not_fed_but_a_router_feeds_everything() -> void:
	var router := Router.new()
	router.name = "Router"
	_n["Core"].add_child(router)
	assert_str(GearPlate.plate_text(Device.of(_n["Switch"]))).is_equal("SWITCH · feeds CAMERA, PANEL, PRINTER")
	assert_str(GearPlate.plate_text(Device.of(_n["Core"]))).is_equal("CORE · feeds SWITCH")


func test_plate_text_truncates_past_four_names() -> void:
	var names: Array[String] = ["A", "B", "C", "D", "E", "F"]
	assert_str(GearPlate.format("SW-VAULT", names)).is_equal("SW-VAULT · feeds A, B, C, D, +2")
	assert_str(GearPlate.format("SW-VAULT", names.slice(0, 4))).is_equal("SW-VAULT · feeds A, B, C, D")
	var none: Array[String] = []
	assert_str(GearPlate.format("SW-EMPTY", none)).is_equal("SW-EMPTY")
