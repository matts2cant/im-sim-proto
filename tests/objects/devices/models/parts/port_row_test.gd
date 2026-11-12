extends GdUnitTestSuite
## PortRow (ADR 0130): one socket per label, a port light above each (lit when the label names a
## device, dark when empty), a label per named socket (vertical, or flat), an uplink ring in the
## kind's colour. Built on a minimal model, not on a shipped device.


func test_n_labels_give_n_sockets_and_lit_lights() -> void:
	var row := _row(PackedStringArray(["SW-CORE", "PC-1", "AP-YARD"]))

	assert_int(row.socket_count()).is_equal(3)
	assert_int(_socket_boxes(row)).is_equal(3)
	assert_int(row.lights.size()).is_equal(3)
	for light in row.lights:
		assert_bool(_color(light).is_equal_approx(ModelStyle.ONLINE)).is_true()
	assert_int(row.label_nodes.size()).is_equal(3)
	assert_str(row.label_nodes[1].text).is_equal("PC-1")


func test_empty_labels_give_dark_lights_and_no_text() -> void:
	var row := _row(PackedStringArray(["SW-CORE", "", " "]))

	assert_int(_socket_boxes(row)).is_equal(3)
	assert_bool(_color(row.lights[0]).is_equal_approx(ModelStyle.ONLINE)).is_true()
	assert_bool(_color(row.lights[1]).is_equal_approx(ModelStyle.DARK)).is_true()
	assert_bool(_color(row.lights[2]).is_equal_approx(ModelStyle.DARK)).is_true()
	assert_int(row.label_nodes.size()).is_equal(1)


func test_labels_run_down_under_their_socket_or_lie_flat() -> void:
	var row := _row(PackedStringArray(["RTR-01", "SW-SEC"]))

	var label := row.label_nodes[1]
	# Turned clockwise: the text's own x runs down the front, starting under the second socket.
	assert_bool(label.transform.basis.x.is_equal_approx(Vector3.DOWN)).is_true()
	assert_float(label.position.x).is_equal_approx(row.pitch + row.socket().x * 0.5, 0.0001)
	assert_float(label.position.y).is_less(-row.socket().y)
	row.flat_labels = true
	assert_bool(row.label_nodes[1].transform.basis.x.is_equal_approx(Vector3.RIGHT)).is_true()


func test_relabelling_rebuilds_the_row() -> void:
	var row := _row(PackedStringArray(["A", "B"]))

	row.labels = PackedStringArray(["A", "", "C", "D"])

	assert_int(_socket_boxes(row)).is_equal(4)
	assert_int(row.lights.size()).is_equal(4)
	assert_int(row.label_nodes.size()).is_equal(3)
	assert_int(row.find_children("PortLight*", "MeshInstance3D", false, false).size()).is_equal(4)


func test_the_uplink_ring_takes_the_kind_colour() -> void:
	var row := _row(PackedStringArray(["", "UPLINK"]), &"object.router")
	row.uplink = 1

	var ring := row.get_node("UplinkRing") as MeshInstance3D
	var material := ring.mesh.surface_get_material(0) as StandardMaterial3D
	var router := DeviceKinds.shipped().kind_with_tag(&"object.router")
	assert_bool(material.albedo_color.is_equal_approx(router.color)).is_true()


func _row(labels: PackedStringArray, kind_tag: StringName = &"object.network_switch") -> PortRow:
	var model := DeviceModel.new()
	model.kind_tag = kind_tag
	var row := PortRow.new()
	row.labels = labels
	model.add_child(row)
	add_child(model)
	auto_free(model)
	return row


# Sockets are one merged mesh of boxes (24 vertices each).
func _socket_boxes(row: PortRow) -> int:
	var mesh := (row.get_node("Sockets") as MeshInstance3D).mesh
	if mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 24


func _color(light: MeshInstance3D) -> Color:
	return light.get_instance_shader_parameter(&"led_color") as Color
