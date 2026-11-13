extends GdUnitTestSuite
## Integration (M13 one light, ADR 0122 amendment 2; ADR 0130 step 3): one light per device. A device
## without a model whose entity has a DeviceLamp shows its network state on the lamp: the owner's
## colour while up, amber blinking when cut off, dark when unpowered or disabled, the owner's colour
## again with the link. Without a model or a lamp it shows nothing (nothing is placed any more).
## Minimal entities built from components (network_fixtures.body_device):
##   Switch (gear) ── Box (DeviceLamp + a lamp mesh, DeviceSwitch), Plain (no lamp)
##   Lone: a DeviceLamp, no cables (no StatusLight)
## The shipped camera (its watch lamp) and a door with a keypad (its controller's boxes' lock lights,
## ADR 0130) use the same component.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const DoorHelpers := preload("res://tests/objects/door/door_helpers.gd")
const ORIGIN := Vector3(600, 0, -600)
const OWN := Color(0.2, 0.4, 1.0)

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_n.clear()
	_n["Switch"] = Net.body_device(_root, "Switch", ORIGIN + Vector3(0, 1.5, 0), [], true)
	ActorState.set_tag(_n["Switch"], DeviceNetwork.NETWORK_GEAR, true)
	var receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.ENABLE)
	]
	_n["Box"] = Net.body_device(_root, "Box", ORIGIN + Vector3(2, 1.5, 0), receptrons, true)
	var toggle := DeviceSwitch.new()
	toggle.name = "DeviceSwitch"
	_n["Box"].add_child(toggle)
	_add_lamp(_n["Box"], true)
	_n["Plain"] = Net.body_device(_root, "Plain", ORIGIN + Vector3(4, 1.5, 0))
	_n["Lone"] = Net.body_device(_root, "Lone", ORIGIN + Vector3(6, 1.5, 0))
	_add_lamp(_n["Lone"], true)
	for leaf: String in ["Box", "Plain"]:
		Net.link(_n[leaf], _n["Switch"])
	# The lights attach deferred, once the cables are in.
	await get_tree().process_frame
	_lamp("Box").show_own(OWN, true)
	_lamp("Lone").show_own(OWN, true)


func after_test() -> void:
	StimulusSystem.clear()


# A DeviceLamp on `entity`, with a small lamp mesh on its front when `with_mesh`.
func _add_lamp(entity: Node3D, with_mesh: bool) -> DeviceLamp:
	var lamp := DeviceLamp.new()
	lamp.name = "DeviceLamp"
	if with_mesh:
		var mesh := MeshInstance3D.new()
		mesh.name = "LampMesh"
		var sphere := SphereMesh.new()
		sphere.radius = 0.02
		sphere.height = 0.04
		mesh.mesh = sphere
		mesh.position = Vector3(0.1, 0.1, 0.21)
		entity.add_child(mesh)
		lamp.lamps = [^"../LampMesh"]
	entity.add_child(lamp)
	return lamp


func _lamp(entity_name: String) -> DeviceLamp:
	return DeviceLamp.of(_n[entity_name])


func _power(entity_name: String, on: bool) -> void:
	(_n[entity_name].get_node("Powered") as Powered).on = on


func _command(action: StringName, entity_name: String) -> void:
	StimulusSystem.emit(Device.command_stimulus(action, _n[entity_name]))
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame


func _assert_shows(lamp: DeviceLamp, color: Color, blinking: bool, label: String) -> void:
	var shown := lamp.color()
	assert_bool(shown.is_equal_approx(color)).override_failure_message("%s shows %s" % [label, shown]).is_true()
	assert_bool(lamp.blinking()).override_failure_message(label + " blink").is_equal(blinking)
	# Painted on the meshes (the shared status light shader's per-instance parameters).
	for mesh in lamp.meshes():
		var painted: Color = mesh.get_instance_shader_parameter(&"led_color")
		assert_bool(painted.is_equal_approx(color)).override_failure_message(label + " painted").is_true()
		assert_float(float(mesh.get_instance_shader_parameter(&"blink"))).is_equal(1.0 if blinking else 0.0)


func test_a_device_with_a_lamp_shows_it_and_one_without_shows_nothing() -> void:
	var light := StatusLight.of(_n["Box"])
	assert_object(light).is_not_null()
	assert_array(light.indicators()).contains_exactly(_lamp("Box").meshes())
	# No model, no lamp: no light is placed on it.
	assert_object(StatusLight.of(_n["Plain"])).is_null()
	_assert_shows(_lamp("Box"), OWN, false, "up")


func test_cut_off_blinks_amber_and_the_link_brings_the_owner_colour_back() -> void:
	_power("Switch", false)
	_assert_shows(_lamp("Box"), StatusLight.COLORS[StatusLight.State.CUT_OFF], true, "cut off")
	# The owner's colour changes underneath: the network state still wins.
	_lamp("Box").show_own(Color.RED, true)
	_assert_shows(_lamp("Box"), StatusLight.COLORS[StatusLight.State.CUT_OFF], true, "cut off, red owner")
	_power("Switch", true)
	_assert_shows(_lamp("Box"), Color.RED, false, "back")


func test_unpowered_or_disabled_is_dark_then_the_owner_colour() -> void:
	var dark := StatusLight.COLORS[StatusLight.State.DARK]
	_power("Box", false)
	_assert_shows(_lamp("Box"), dark, false, "unpowered")
	_power("Box", true)
	_assert_shows(_lamp("Box"), OWN, false, "powered")
	await _command(Device.DISABLE, "Box")
	_assert_shows(_lamp("Box"), dark, false, "disabled")
	await _command(Device.ENABLE, "Box")
	_assert_shows(_lamp("Box"), OWN, false, "enabled")
	_lamp("Box").show_own(OWN, false)
	_assert_shows(_lamp("Box"), dark, false, "owner unlit")


func test_off_any_network_the_lamp_shows_the_owner_colour() -> void:
	assert_object(StatusLight.of(_n["Lone"])).is_null()
	_assert_shows(_lamp("Lone"), OWN, false, "lone")


func test_a_lamp_that_gains_its_meshes_later_shows_the_state() -> void:
	# A lamp added after the device attached (a door's hardware built later): attached again, the light
	# drives it once it has a mesh.
	var lamp := _add_lamp(_n["Plain"], false)
	var light := StatusLight.attach(Device.of(_n["Plain"]))
	assert_object(light).is_not_null()
	assert_array(light.indicators()).is_empty()
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	_n["Plain"].add_child(mesh)
	var meshes: Array[MeshInstance3D] = [mesh]
	lamp.set_meshes(meshes)
	assert_array(light.indicators()).contains_exactly(meshes)
	assert_int(lamp.network).is_equal(StatusLight.State.UP)
	var none: Array[MeshInstance3D] = []
	lamp.set_meshes(none)
	assert_array(light.indicators()).is_empty()


func test_a_camera_that_sees_the_player_is_red_until_cut_off() -> void:
	var camera := (load("res://objects/camera/security_camera.tscn") as PackedScene).instantiate() as Node3D
	camera.position = ORIGIN + Vector3(0, 2.5, 10)
	_root.add_child(camera)
	Net.link(camera, _n["Switch"])
	await get_tree().process_frame
	var lamp := DeviceLamp.of(camera)
	var behaviour := SecurityCamera.of(camera)
	assert_array(StatusLight.of(camera).indicators()).override_failure_message("the lamp only").contains_exactly(
		lamp.meshes()
	)
	_assert_shows(lamp, behaviour.config.idle_color, false, "idle")
	behaviour.model.stop_sweep()
	Fixtures.entity(_root, "Decoy", ORIGIN + Vector3(0, 0, 16), [], [&"actor.player"])
	for i in 400:
		if behaviour.meter.detected:
			break
		await get_tree().physics_frame
	assert_bool(behaviour.meter.detected).is_true()
	_assert_shows(lamp, behaviour.config.detected_color, false, "detected")
	# Cut off while it still sees the player: the network state wins.
	_power("Switch", false)
	await get_tree().physics_frame
	assert_bool(behaviour.is_watching()).is_true()
	_assert_shows(lamp, StatusLight.COLORS[StatusLight.State.CUT_OFF], true, "cut off")
	_power("Switch", true)
	await get_tree().physics_frame
	_assert_shows(lamp, behaviour.config.detected_color, false, "linked again")


func test_a_door_with_a_keypad_shows_its_lock_lights_and_no_extra_led() -> void:
	var door := _door("KeypadDoor", Vector3(0, 0, 20), true)
	var other := _door("BareDoor", Vector3(4, 0, 20), false)
	await get_tree().process_frame
	# The keypad's boxes are the door's controller (ADR 0130): its lamp is their lock lights.
	var controller := Door.of(door).hardware.controller.entity
	var lamp := DeviceLamp.of(controller)
	# A keypad box on each face of the wall: two lock lights, one per side.
	assert_int(lamp.meshes().size()).is_equal(2)
	assert_array(StatusLight.of(controller).indicators()).contains_exactly_in_any_order(lamp.meshes())
	DoorHelpers.lock(door)
	_assert_shows(lamp, Door.LOCKED_COLOUR, false, "locked")
	Lockable.of(door).unlock(null, &"test")
	_assert_shows(lamp, Door.UNLOCKED_COLOUR, false, "unlocked")
	_power("Switch", false)
	_assert_shows(lamp, StatusLight.COLORS[StatusLight.State.CUT_OFF], true, "cut off")
	_power("Switch", true)
	_assert_shows(lamp, Door.UNLOCKED_COLOUR, false, "linked again")
	# Without wall boxes: no controller, no device, no light at all.
	assert_object(Door.of(other).hardware.controller).is_null()
	assert_object(Device.of(other)).is_null()
	assert_object(StatusLight.of(other)).is_null()


# A door at `at`; with a keypad, its controller is cabled to the switch.
func _door(door_name: String, at: Vector3, keypad: bool) -> Node3D:
	var door := (load("res://objects/door/door.tscn") as PackedScene).instantiate() as Node3D
	door.name = door_name
	door.position = ORIGIN + at
	if keypad:
		DoorHelpers.add_keypad(door, &"lamp_test", "1234")
	_root.add_child(door)
	if keypad:
		Net.link(Door.of(door).hardware.controller.entity, _n["Switch"])
	return door
