extends GdUnitTestSuite
## ModelFace and StatusLight on minimal entities (ADR 0130 step 2): a device built from any device
## model (a DeviceModel with a StatusLed, a PortRow and a NamePlate, made in code) shows its state on
## the model's own light, each cable on the next socket (the far end's name, a port light lit while
## both ends are up), its name on the plate; a model without a light shows none; more cables than
## sockets is reported. Not the shipped scenes (device_scenes_test.gd covers those).
##   Box (model: 1 LED, 2 sockets) ── A, B; C cabled in one test only (three cables, two sockets)
##   Plain (model without a light)

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(560, 0, -560)

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_n.clear()
	_n["Box"] = _modelled("Box", Vector3.ZERO, true, 2)
	_n["A"] = Net.body_device(_root, "A", ORIGIN + Vector3(2, 1, 0), [], true, 10.0)
	_n["B"] = Net.body_device(_root, "B", ORIGIN + Vector3(4, 1, 0), [], true, 10.0)
	_n["Plain"] = _modelled("Plain", Vector3(0, 0, 3), false, 0)
	Net.link(_n["Box"], _n["A"])
	Net.link(_n["B"], _n["Box"])
	Net.link(_n["Plain"], _n["A"])
	for entity_name: String in _n:
		_n[entity_name].set_meta(&"display_name", entity_name.to_upper() + "-1")


func after_test() -> void:
	StimulusSystem.clear()


func test_a_cable_takes_the_next_socket_and_a_router_the_uplink() -> void:
	assert_array(ModelFace.socket_order([false, false], [false, false, false])).is_equal([0, 1])
	# The uplink (socket 2) goes to the router; the others fill the plain sockets, then what is left.
	assert_array(ModelFace.socket_order([false, true, false], [false, false, true])).is_equal([0, 2, 1])
	assert_array(ModelFace.socket_order([false, false, false], [false, true])).is_equal([0, 1, -1])
	assert_int(ModelFace.excess(3, 2)).is_equal(1)
	assert_int(ModelFace.excess(2, 2)).is_equal(0)
	assert_int(ModelFace.excess(9, ModelFace.NO_LIMIT)).is_equal(0)


func test_a_long_name_shrinks_then_is_cut_to_its_label_room() -> void:
	assert_array(PortRow.fit_label("SW-A", 0.004, 0.05)).is_equal(["SW-A", 0.004])
	var shrunk := PortRow.fit_label("SW-OFFICE", 0.004, 0.02)
	assert_str(shrunk[0] as String).is_equal("SW-OFFICE")
	assert_float(shrunk[1] as float).is_less(0.004)
	var cut := PortRow.fit_label("SIREN-OFFICE-GROUND", 0.004, 0.02)
	assert_float(cut[1] as float).is_equal_approx(0.004 * PortRow.MIN_SHRINK, 1e-6)
	assert_float(ModelText.width_of(cut[0] as String, cut[1] as float)).is_less_equal(0.02)


func test_the_model_light_follows_the_device() -> void:
	await _attached()
	var led := _led("Box")

	assert_array(StatusLight.of(_n["Box"]).indicators()).contains_exactly([led])
	assert_bool(_color(led).is_equal_approx(StatusLight.COLORS[StatusLight.State.UP])).is_true()
	assert_float(_blink(led)).is_equal(0.0)
	_power("A", false)
	_power("B", false)
	assert_bool(_color(led).is_equal_approx(StatusLight.COLORS[StatusLight.State.CUT_OFF])).is_true()
	assert_float(_blink(led)).is_equal(1.0)
	_power("A", true)
	Breakable.of(_n["Box"]).take_damage(&"ballistic", 100.0)
	assert_bool(_color(led).is_equal_approx(StatusLight.COLORS[StatusLight.State.DISABLED])).is_true()
	_power("Box", false)
	assert_bool(_color(led).is_equal_approx(StatusLight.COLORS[StatusLight.State.DARK])).is_true()
	assert_float(_blink(led)).is_equal(0.0)


func test_a_model_without_a_light_shows_none() -> void:
	await _attached()

	var light := StatusLight.of(_n["Plain"])
	assert_object(light).is_not_null()
	assert_array(light.indicators()).is_empty()
	assert_object(light.led).override_failure_message("no LED placed on a model").is_null()


func test_ports_name_the_far_ends_and_light_while_both_are_up() -> void:
	await _attached()
	var row := _row("Box")

	assert_array(Array(row.labels)).is_equal(["A-1", "B-1"])
	assert_array(StatusLight.of(_n["Box"]).port_lights).is_equal(row.lights)
	assert_bool(_color(row.lights[0]).is_equal_approx(StatusLight.PORT_ON)).is_true()
	_power("A", false)
	assert_bool(_color(row.lights[0]).is_equal_approx(StatusLight.COLORS[StatusLight.State.DARK])).is_true()
	assert_bool(_color(row.lights[1]).is_equal_approx(StatusLight.PORT_ON)).is_true()
	# The label stays: the cable is still there.
	assert_str(row.labels[0]).is_equal("A-1")
	_power("Box", false)
	assert_bool(_color(row.lights[1]).is_equal_approx(StatusLight.COLORS[StatusLight.State.DARK])).is_true()


func test_the_plate_shows_the_display_name() -> void:
	await _attached()

	var plate := _n["Box"].find_children("*", "NamePlate", true, false)[0] as NamePlate
	assert_str(plate.text).is_equal("BOX-1")


func test_more_cables_than_sockets_is_reported() -> void:
	var extra := Net.body_device(_root, "C", ORIGIN + Vector3(6, 1, 0), [], true, 10.0)
	Net.link(extra, _n["Box"])
	await _attached()

	assert_int(ModelFace.sockets(_n["Box"])).is_equal(2)
	assert_str(ModelFace.cable_error(Device.of(_n["Box"]))).contains("3 cables for 2 sockets")
	assert_str(ModelFace.cable_error(Device.of(_n["A"]))).is_empty()
	# The third cable finds no socket: no label, no light.
	var light := StatusLight.of(_n["Box"])
	assert_int(light.port_lights.size()).is_equal(3)
	assert_object(light.port_lights[2]).is_null()
	assert_int(ModelFace.sockets(_n["Plain"])).is_equal(ModelFace.HIDDEN_SOCKETS)
	assert_int(ModelFace.sockets(_n["A"])).is_equal(ModelFace.NO_LIMIT)


# A device entity built from a model made in code: a DeviceModel of the switch kind with a status
# light (`led`), a row of `sockets` ports (none: no row) and a name plate.
func _modelled(entity_name: String, at: Vector3, led: bool, sockets: int) -> Node3D:
	var entity := Net.body_device(_root, entity_name, ORIGIN + at, [], true, 10.0)
	entity.get_node("Mesh").queue_free()
	var model := DeviceModel.new()
	model.name = "Model"
	model.kind_tag = &"object.network_switch"
	if led:
		var light := StatusLed.new()
		light.name = "StatusLed"
		model.add_child(light)
	if sockets > 0:
		var row := PortRow.new()
		row.name = "PortRow"
		var blank := PackedStringArray()
		blank.resize(sockets)
		row.labels = blank
		row.position = Vector3(0.0, -0.02, 0.0)
		model.add_child(row)
	var plate := NamePlate.new()
	plate.name = "NamePlate"
	plate.position = Vector3(0.0, 0.03, 0.0)
	model.add_child(plate)
	entity.add_child(model)
	return entity


# The lights attach deferred, once the cables are in.
func _attached() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _led(entity_name: String) -> MeshInstance3D:
	return (_n[entity_name].get_node("Model/StatusLed") as StatusLed).led


func _row(entity_name: String) -> PortRow:
	return _n[entity_name].get_node("Model/PortRow") as PortRow


func _power(entity_name: String, on: bool) -> void:
	(_n[entity_name].get_node("Powered") as Powered).on = on


func _color(mesh: MeshInstance3D) -> Color:
	return mesh.get_instance_shader_parameter(&"led_color") as Color


func _blink(mesh: MeshInstance3D) -> float:
	return float(mesh.get_instance_shader_parameter(&"blink"))
