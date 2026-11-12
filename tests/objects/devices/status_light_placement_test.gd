extends GdUnitTestSuite
## Integration (M13 playtest fix, ADR 0122 amendment): status lights sit on their device, never in
## the air. Every shipped device scene (any .tscn under objects/ whose entity has a Device), cabled
## to a stand-in switch, gets its LED (network gear also its port lights) on its visible surface:
## each light's centre and back corners lie within MAX_GAP of a visible mesh of the entity, and it
## faces the front (+Z). A minimal entity built from components shows the rule is generic: the LED
## skips a protrusion and an antenna for the flat plate, and rides with the part it sits on.
## One light per device (ADR 0122 amendment 2): every device scene shows its own lamp or the LED,
## port lights only on network gear, and no other small glowing mesh.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(-560, 0, 560)
const MAX_GAP := 0.01
## A glowing mesh smaller than this (longest side, m) reads as a light (the turret's old 5 cm sight).
const SMALL := 0.08
const DEVICE_SCRIPT := "res://objects/devices/device.gd"

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_every_device_scene_gets_its_lights_on_its_surface() -> void:
	var scenes := _device_scenes("res://objects")
	assert_int(scenes.size()).is_greater_equal(12)
	var peer := Net.body_device(_root, "Peer", ORIGIN + Vector3(0, 1, -4))
	ActorState.set_tag(peer, DeviceNetwork.NETWORK_GEAR, true)
	var placed: Array[Node3D] = []
	for i in scenes.size():
		var entity := (load(scenes[i]) as PackedScene).instantiate() as Node3D
		entity.position = ORIGIN + Vector3(i * 3.0, 1.0, 0.0)
		_root.add_child(entity)
		Net.link(entity, peer)
		placed.append(entity)
	# The lights attach deferred, once the cables are in.
	await get_tree().process_frame
	for entity in placed:
		var light := StatusLight.of(entity)
		var label := entity.scene_file_path
		assert_object(light).override_failure_message(label).is_not_null()
		if light.led != null:
			_assert_on_surface(entity, light.led, label + " LED")
		for port in light.port_lights:
			_assert_on_surface(entity, port, label + " " + String(port.name))
	var switch := StatusLight.of(_by_scene(placed, "network_switch.tscn"))
	assert_int(switch.port_lights.size()).override_failure_message("gear gets port lights").is_equal(1)


func test_every_device_scene_shows_one_light() -> void:
	# One light per device (ADR 0122 amendment 2): its own lamp or the LED, never both; port lights
	# only on network gear; no other small glowing mesh left on it (screens are bigger than SMALL).
	var scenes := _device_scenes("res://objects")
	var peer := Net.body_device(_root, "Peer", ORIGIN + Vector3(0, 1, -8))
	ActorState.set_tag(peer, DeviceNetwork.NETWORK_GEAR, true)
	var placed: Array[Node3D] = []
	for i in scenes.size():
		var entity := (load(scenes[i]) as PackedScene).instantiate() as Node3D
		entity.position = ORIGIN + Vector3(i * 3.0, 1.0, -12.0)
		_root.add_child(entity)
		Net.link(entity, peer)
		placed.append(entity)
	await get_tree().process_frame
	var lamps := 0
	for entity in placed:
		var light := StatusLight.of(entity)
		var label := entity.scene_file_path
		var lamp := DeviceLamp.of(entity)
		var has_lamp := lamp != null and lamp.has_lamps()
		lamps += 1 if has_lamp else 0
		assert_bool(has_lamp != (light.led != null)).override_failure_message(label + ": lamp or LED").is_true()
		assert_int(light.indicators().size()).override_failure_message(label).is_greater(0)
		var gear := DeviceNetwork.is_network_gear(Device.of(entity))
		assert_bool(light.port_lights.is_empty() != gear).override_failure_message(label + " ports").is_true()
		var allowed: Array[MeshInstance3D] = light.indicators()
		allowed.append_array(light.port_lights)
		for glow in _small_glowing(entity):
			assert_bool(allowed.has(glow)).override_failure_message("%s: %s glows" % [label, glow.name]).is_true()
	# The camera's watch lamp is one of them (a door's lock lights need a lock: device_lamp_test).
	assert_int(lamps).is_greater_equal(1)


func test_a_door_light_rides_on_its_leaf() -> void:
	var peer := Net.body_device(_root, "Peer", ORIGIN + Vector3(0, 1, -4))
	var entity := (load("res://objects/door/door.tscn") as PackedScene).instantiate() as Node3D
	entity.position = ORIGIN + Vector3(0, 0, 4)
	_root.add_child(entity)
	Net.link(entity, peer)
	await get_tree().process_frame
	var led := StatusLight.of(entity).led
	var closed := led.global_position
	var door := Door.of(entity)
	# In the doorway's top-left corner while closed (the leaf's rim hides in the jamb).
	var local := entity.to_local(closed)
	var doorway := door.settings.doorway
	assert_float(local.x).is_between(-doorway.x * 0.5, -doorway.x * 0.5 + 0.12)
	assert_float(local.y).is_between(doorway.y - 0.12, doorway.y)
	door.load_state({"open": true})
	_assert_on_surface(entity, led, "open door LED")
	assert_vector(led.global_position - closed).is_equal_approx(
		entity.global_basis * door.settings.travel, Vector3.ONE * 0.001
	)


func test_a_minimal_device_gets_its_led_on_the_flat_plate_and_carries_it() -> void:
	# A 0.4 m box (body_device's Mesh) with a thin antenna above its top-left corner, a deep hood
	# along its top front edge, and a plate on an arm that pans.
	var entity := Net.body_device(_root, "Box", ORIGIN + Vector3(0, 1, 8), [], true)
	var peer := Net.body_device(_root, "Peer", ORIGIN + Vector3(3, 1, 8))
	_part(entity, "Antenna", Vector3(0.01, 0.4, 0.01), Vector3(-0.17, 0.4, 0.0))
	_part(entity, "Hood", Vector3(0.4, 0.03, 0.15), Vector3(0.0, 0.185, 0.27))
	Net.link(entity, peer)
	await get_tree().process_frame
	var light := StatusLight.of(entity)
	_assert_on_surface(entity, light.led, "minimal LED")
	var on := entity.to_local(light.led.global_position)
	# On the box's front face (z 0.2), below the hood, near the left edge: not on the antenna or hood.
	assert_float(on.z).is_between(0.2, 0.21)
	assert_float(on.x).is_less(-0.1)
	assert_float(on.y).is_between(0.0, 0.17)
	assert_object(light.led.get_parent()).is_same(entity.get_node("Mesh"))


func test_a_light_rides_with_the_moving_part_it_sits_on() -> void:
	var entity := Net.body_device(_root, "Mount", ORIGIN + Vector3(0, 1, 12), [], true)
	var peer := Net.body_device(_root, "Peer", ORIGIN + Vector3(3, 1, 12))
	var arm := Node3D.new()
	arm.name = "Arm"
	entity.add_child(arm)
	var head := _part(arm, "Head", Vector3(0.3, 0.2, 0.3), Vector3(0.0, 0.35, 0.1))
	Net.link(entity, peer)
	await get_tree().process_frame
	var led := StatusLight.of(entity).led
	assert_object(led.get_parent()).is_same(head)
	arm.rotate_y(0.8)
	_assert_on_surface(entity, led, "panned head LED")
	# Freed with its light.
	StatusLight.of(entity).free()
	await get_tree().process_frame
	assert_bool(is_instance_valid(led)).is_false()


func _part(parent: Node3D, part_name: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


# Checks `light`'s centre and back corners lie within MAX_GAP of a visible mesh of `entity` (the
# lights' own meshes left out), and that it faces the entity's front.
func _assert_on_surface(entity: Node3D, light: MeshInstance3D, label: String) -> void:
	assert_object(light).override_failure_message(label).is_not_null()
	var faces := _faces(entity)
	var half := (light.mesh as BoxMesh).size * 0.5
	var points: Array[Vector3] = [light.global_position]
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		points.append(light.global_transform * Vector3(corner.x * half.x, corner.y * half.y, -half.z))
	for point in points:
		var gap := _distance(point, faces)
		assert_float(gap).override_failure_message("%s: %.3f m off the surface" % [label, gap]).is_less(MAX_GAP)
	var facing := light.global_basis.z.normalized().dot(entity.global_basis.z)
	assert_float(facing).override_failure_message("%s faces %.2f" % [label, facing]).is_greater(0.5)


func _faces(entity: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		if part.mesh == StatusLight.LED_MESH or part.mesh == StatusLight.PORT_MESH:
			continue
		var place := part.global_transform
		for vertex in part.mesh.get_faces():
			faces.append(place * vertex)
	return faces


func _distance(point: Vector3, faces: PackedVector3Array) -> float:
	var best := INF
	for i in range(0, faces.size(), 3):
		best = minf(best, point.distance_to(_closest(point, faces[i], faces[i + 1], faces[i + 2])))
	return best


func _closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() > 1e-12:
		var on_plane := Plane(normal.normalized(), a).project(p)
		var weights := Geometry3D.get_triangle_barycentric_coords(on_plane, a, b, c)
		if weights.x >= 0.0 and weights.y >= 0.0 and weights.z >= 0.0:
			return on_plane
	var best := Geometry3D.get_closest_point_to_segment(p, a, b)
	for edge: Vector3 in [
		Geometry3D.get_closest_point_to_segment(p, b, c), Geometry3D.get_closest_point_to_segment(p, c, a)
	]:
		if p.distance_squared_to(edge) < p.distance_squared_to(best):
			best = edge
	return best


# The visible meshes of `entity` under SMALL (longest side, m) that glow: an emissive or unshaded
# material, or a shader one (the status lights').
func _small_glowing(entity: Node3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var size := (part.global_basis.get_scale() * part.get_aabb().size).abs()
		if maxf(size.x, maxf(size.y, size.z)) >= SMALL:
			continue
		var material := part.material_override
		if material == null and part.mesh.get_surface_count() > 0:
			material = part.get_active_material(0)
		var base := material as BaseMaterial3D
		var glows := material is ShaderMaterial
		if base != null:
			glows = base.emission_enabled or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		if glows:
			found.append(part)
	return found


# The .tscn files under `dir` whose scene uses the Device component.
func _device_scenes(dir: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_device_scenes(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn") and DEVICE_SCRIPT in FileAccess.get_file_as_string(dir.path_join(file)):
			found.append(dir.path_join(file))
	return found


func _by_scene(entities: Array[Node3D], file: String) -> Node3D:
	for entity in entities:
		if entity.scene_file_path.get_file() == file:
			return entity
	return null
