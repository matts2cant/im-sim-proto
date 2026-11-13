extends GdUnitTestSuite
## Integration (ADR 0122 amendment 2, ADR 0130): one light per device, and nothing placed. Every
## shipped device scene (any .tscn under objects/ whose entity has a Device), cabled to a stand-in
## switch, is built from a device model: it shows its model's one light (a camera's as its lamp) or
## none, a light per socket of its port rows, and no other small glowing mesh.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(-560, 0, 560)
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


func test_every_device_scene_shows_its_model_light_only() -> void:
	# No other small glowing mesh is left on it (screens are bigger than SMALL).
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
		assert_bool(ModelFace.has_model(entity)).override_failure_message(label + ": no model").is_true()
		assert_object(light).override_failure_message(label).is_not_null()
		var lamp := DeviceLamp.of(entity)
		lamps += 1 if lamp != null and lamp.has_lamps() else 0
		var allowed: Array[MeshInstance3D] = light.indicators()
		allowed.append_array(light.port_lights)
		# Its own lights only, each driven (the camera's as its lamp); a socket's light per port.
		var leds := ModelFace.leds(entity).size()
		assert_int(leds).override_failure_message(label + ": one light at most").is_less_equal(1)
		assert_int(light.indicators().size()).override_failure_message(label).is_equal(leds)
		var rows := ModelFace.rows(entity)
		assert_bool(light.port_lights.is_empty() == rows.is_empty()).override_failure_message(label).is_true()
		for row in rows:
			allowed.append_array(row.lights)
		for glow in _small_glowing(entity):
			assert_bool(allowed.has(glow)).override_failure_message("%s: %s glows" % [label, glow.name]).is_true()
	# The camera's watch lamp is one of them (a door controller's lock lights need a door:
	# device_lamp_test, door_controller_test).
	assert_int(lamps).is_greater_equal(1)


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


# The .tscn files under `dir` whose scene uses the Device component and has a body of its own (a
# door controller's body is the wall boxes its door builds: door_controller_test.gd).
func _device_scenes(dir: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_device_scenes(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tscn"):
			continue
		var text := FileAccess.get_file_as_string(dir.path_join(file))
		if DEVICE_SCRIPT in text and ("MeshInstance3D" in text or "instance=" in text):
			found.append(dir.path_join(file))
	return found
