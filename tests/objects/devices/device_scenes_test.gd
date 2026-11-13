extends GdUnitTestSuite
## Every device scene built from a device model (ADR 0130 step 2) loads with its components, its kind
## colour strip (the kind its tags give), its one driven light (none on wall jacks, panic buttons and
## lasers; the camera's lamp), its socket count, and no more cables than sockets. Each stands alone,
## cabled to one stand-in, under one root far from the other suites.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(-600, 0, 600)
## scene: [driven lights, sockets].
const SCENES: Dictionary[String, Array] = {
	"res://objects/network/access_point.tscn": [1, 1],
	"res://objects/network/wall_jack.tscn": [0, 1],
	"res://objects/network/switch_rack.tscn": [1, 24],
	"res://objects/network/switch_desk.tscn": [1, 5],
	"res://objects/network/router_rack.tscn": [1, 9],
	"res://objects/network/router_desk.tscn": [1, 5],
	"res://objects/camera/security_camera.tscn": [1, 1],
	"res://objects/turret/turret.tscn": [1, 1],
	"res://objects/alarm/siren.tscn": [1, 1],
	"res://objects/alarm/radio_base_station.tscn": [1, 1],
	"res://objects/alarm/panic_button.tscn": [0, 1],
	"res://objects/alarm/alarm_controller.tscn": [1, 1],
	"res://objects/alarm/alarm_controller_rack.tscn": [1, 1],
	"res://objects/laser/laser_array.tscn": [0, 1],
	"res://objects/computer/computer.tscn": [1, 1],
	"res://objects/computer/server_rack.tscn": [1, 1],
}
const COMPONENTS: Array[String] = ["Tags", "Attributes", "StimulusReceiver", "Breakable", "Device"]

var _root: Node3D
var _entities: Dictionary[String, Node3D] = {}


func before() -> void:
	EventLog.clear()
	_root = Node3D.new()
	add_child(_root)
	var i := 0
	for path: String in SCENES:
		var entity := (load(path) as PackedScene).instantiate() as Node3D
		entity.position = ORIGIN + Vector3(float(i) * 2.0, 1.0, 0.0)
		_root.add_child(entity)
		var peer := Net.body_device(_root, "Peer%d" % i, ORIGIN + Vector3(float(i) * 2.0, 1.0, 3.0), [], true)
		peer.set_meta(&"display_name", "PEER-%d" % i)
		Net.link(peer, entity)
		_entities[path] = entity
		i += 1
	# The lights attach deferred, once the cables are in.
	await get_tree().process_frame
	await get_tree().process_frame


func after() -> void:
	_root.free()


func test_every_scene_has_its_components_and_a_model() -> void:
	for path: String in SCENES:
		var entity := _entities[path]
		for part in COMPONENTS:
			assert_object(entity.get_node_or_null(part)).override_failure_message("%s %s" % [path, part]).is_not_null()
		assert_bool(ModelFace.has_model(entity)).override_failure_message(path).is_true()
		assert_object(DeviceKinds.shipped().kind_for(entity)).override_failure_message(path).is_not_null()


func test_every_strip_shows_the_kind_its_tags_give() -> void:
	for path: String in SCENES:
		var entity := _entities[path]
		var kind := DeviceKinds.shipped().kind_for(entity)
		var strips := entity.find_children("*", "KindStrip", true, false)
		assert_int(strips.size()).override_failure_message(path).is_greater(0)
		for strip: Node in strips:
			(
				assert_bool((strip as KindStrip).color().is_equal_approx(kind.color))
				. override_failure_message(path)
				. is_true()
			)


func test_every_scene_drives_its_one_light_or_none() -> void:
	for path: String in SCENES:
		var light := StatusLight.of(_entities[path])
		assert_object(light).override_failure_message(path).is_not_null()
		var expected: int = SCENES[path][0]
		assert_int(light.indicators().size()).override_failure_message(path).is_equal(expected)
		assert_object(light.led).override_failure_message(path + ": no placed LED").is_null()
		assert_object(_entities[path].get_node_or_null("GearPlate")).override_failure_message(path).is_null()


func test_every_scene_has_its_sockets_and_its_cable_fits() -> void:
	for path: String in SCENES:
		var entity := _entities[path]
		assert_int(ModelFace.sockets(entity)).override_failure_message(path).is_equal(SCENES[path][1] as int)
		assert_str(ModelFace.cable_error(Device.of(entity))).override_failure_message(path).is_empty()


func test_a_cabled_socket_names_the_far_end() -> void:
	for path: String in SCENES:
		var rows := ModelFace.rows(_entities[path])
		if rows.is_empty():
			continue
		assert_bool(rows[0].labels[0].begins_with("PEER-")).override_failure_message(path).is_true()
		var light := StatusLight.of(_entities[path])
		assert_array(light.port_states()).override_failure_message(path).is_equal([true])
