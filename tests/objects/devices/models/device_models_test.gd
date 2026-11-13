extends GdUnitTestSuite
## Every device model (ADR 0130 step 0) speaks the design language: its visible size matches the
## design table, its strips in its kind's colour, its kind icon and name plate where the approved look
## has them, one status light (none on wall jacks, panic buttons and lasers) and network ports only on
## network gear, computers, alarm controllers and wall jacks, with the design's socket count. No two
## of its meshes z-fight.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const DIR := "res://objects/devices/models/"
const TOLERANCE := 0.01
## Kinds whose models show network ports.
const PORT_KINDS: Array[StringName] = [
	&"object.network_switch",
	&"object.router",
	&"object.access_point",
	&"object.computer",
	&"object.alarm_controller",
	&"object.wall_jack",
]
## scene: [kind tag, visible width, visible height (-1: not fixed), status light, sockets, strips,
## icon, name plate]. Sizes from the brief, the mockup (design/prototypes/device_language.html) and
## the showroom review (ADR 0130 "second pass"): the access point is a 20 cm ceiling disc without a
## plate or a visible port, the camera and turret keep today's looks (three stripes on the camera's
## head, the turret on the floor), the laser pair is today's head and receiver box; the desktop is its
## tower beside its monitor (the tower alone is checked below).
const MODELS: Dictionary[String, Array] = {
	"switch_rack": [&"object.network_switch", 0.483, 0.0445, true, 24, 1, true, true],
	"switch_desk": [&"object.network_switch", 0.20, 0.042, true, 5, 1, true, true],
	"router_rack": [&"object.router", 0.483, 0.089, true, 9, 1, true, true],
	"router_desk": [&"object.router", 0.22, 0.046, true, 5, 1, true, true],
	"computer_desktop": [&"object.computer", 0.64, 0.40, true, 1, 1, false, true],
	"computer_rack": [&"object.computer", 0.483, 0.089, true, 1, 1, true, true],
	"computer_laptop": [&"object.computer", 0.34, -1.0, true, 1, 1, false, true],
	"alarm_panel": [&"object.alarm_controller", 0.30, 0.38, true, 1, 1, true, true],
	"alarm_rack": [&"object.alarm_controller", 0.483, 0.089, true, 1, 1, true, true],
	"access_point": [&"object.access_point", 0.204, 0.204, true, 0, 1, true, false],
	"wall_jack": [&"object.wall_jack", 0.09, 0.12, false, 1, 1, true, true],
	"door_controller_keypad": [&"object.door_controller", 0.10, 0.20, true, 0, 1, true, false],
	"door_controller_card_reader": [&"object.door_controller", 0.10, 0.20, true, 0, 1, true, false],
	"door_controller_status_box": [&"object.door_controller", 0.10, 0.20, true, 0, 1, true, false],
	"door_controller_control_box": [&"object.door_controller", 0.10, 0.20, true, 0, 1, true, false],
	"camera": [&"object.camera", 0.16, 0.28, true, 0, 3, false, false],
	"turret": [&"object.turret", 0.54, 1.28, true, 0, 1, false, false],
	"siren": [&"object.siren", 0.12, 0.22, true, 0, 1, true, true],
	"radio_base_station": [&"object.radio_base_station", 0.22, 0.29, true, 0, 1, true, true],
	"panic_button": [&"object.panic_button", 0.10, 0.16, false, 0, 1, true, true],
	"laser_emitter": [&"object.laser", 0.12, 0.12, false, 0, 1, false, false],
	"laser_receiver": [&"object.laser", 0.12, 0.12, false, 0, 1, false, false],
}


func test_every_model_matches_its_size() -> void:
	for scene: String in MODELS:
		var model := _load(scene)
		var spec: Array = MODELS[scene]
		var size := _visible_bounds(model).size
		assert_float(size.x).override_failure_message("%s width %s" % [scene, size.x]).is_equal_approx(
			spec[1] as float, TOLERANCE
		)
		if (spec[2] as float) > 0.0:
			assert_float(size.y).override_failure_message("%s height %s" % [scene, size.y]).is_equal_approx(
				spec[2] as float, TOLERANCE
			)


func test_desktop_tower_is_18_by_40_cm() -> void:
	var tower := _load("computer_desktop").get_node("Tower") as MeshInstance3D

	var size := tower.get_aabb().size
	assert_float(size.x).is_equal_approx(0.18, TOLERANCE)
	assert_float(size.y).is_equal_approx(0.40, TOLERANCE)


func test_every_model_has_its_strips_in_its_kind_colour_its_icon_and_its_plate() -> void:
	for scene: String in MODELS:
		var model := _load(scene)
		var spec: Array = MODELS[scene]
		var kind := DeviceKinds.shipped().kind_with_tag(spec[0] as StringName)
		assert_object(model.kind()).override_failure_message(scene).is_same(kind)
		var strips := _parts(model, "KindStrip")
		assert_int(strips.size()).override_failure_message(scene + " strips").is_equal(spec[5] as int)
		for strip: Node in strips:
			var strip_mesh := strip.get_node("Strip") as MeshInstance3D
			var material := (strip_mesh.mesh as PrimitiveMesh).material as StandardMaterial3D
			assert_bool(material.albedo_color.is_equal_approx(kind.color)).override_failure_message(scene).is_true()
		var icons := _parts(model, "KindIcon")
		assert_int(icons.size()).override_failure_message(scene + " icons").is_equal(1 if spec[6] else 0)
		for icon: Node in icons:
			var icon_mesh := icon.get_node("Icon") as MeshInstance3D
			assert_int(icon_mesh.mesh.get_surface_count()).override_failure_message(scene + " icon mesh").is_equal(1)
		var plates := _parts(model, "NamePlate").size()
		assert_int(plates).override_failure_message(scene + " plates").is_equal(1 if spec[7] else 0)


func test_status_lights_and_ports_follow_the_kind() -> void:
	for scene: String in MODELS:
		var model := _load(scene)
		var spec: Array = MODELS[scene]
		var leds := _parts(model, "StatusLed").size()
		assert_int(leds).override_failure_message(scene + " lights").is_equal(1 if spec[3] else 0)
		var rows := _parts(model, "PortRow")
		var sockets := 0
		for row: Node in rows:
			sockets += (row as PortRow).socket_count()
		assert_int(sockets).override_failure_message(scene + " sockets").is_equal(spec[4] as int)
		if not PORT_KINDS.has(spec[0] as StringName):
			assert_int(rows.size()).override_failure_message(scene + " has ports").is_equal(0)


func test_the_router_rings_its_uplink_socket() -> void:
	for scene: String in ["router_rack", "router_desk"]:
		var row := _parts(_load(scene), "PortRow")[0] as PortRow
		assert_int(row.uplink).override_failure_message(scene).is_equal(row.socket_count() - 1)
		assert_object(row.get_node_or_null("UplinkRing")).override_failure_message(scene).is_not_null()


func test_the_door_controller_light_is_its_red_lock_light() -> void:
	var led := _parts(_load("door_controller_keypad"), "StatusLed")[0] as StatusLed

	assert_bool(led.color.is_equal_approx(ModelStyle.RED)).is_true()


func test_no_model_has_coplanar_faces_with_different_materials() -> void:
	for scene: String in MODELS:
		var overlaps := KitGeometry.coplanar_mesh_overlaps(_load(scene))
		assert_array(Array(overlaps)).override_failure_message(scene + "\n" + "\n".join(overlaps)).is_empty()


func _load(scene: String) -> DeviceModel:
	var model := (load(DIR + scene + ".tscn") as PackedScene).instantiate() as DeviceModel
	add_child(model)
	auto_free(model)
	return model


func _parts(model: Node, type: String) -> Array[Node]:
	return model.find_children("*", type, true, false)


# The model's meshes boxed in its own frame (labels lie on the faces: not counted).
func _visible_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
