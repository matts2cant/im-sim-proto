extends GdUnitTestSuite
## The temporary device showroom in the hub (ADR 0130 step 0): every model stands in its area
## against the east wall (z -5.5 to +5.5, up to 4 m out), wall models sit on the wall surface (the
## turret stands on the floor), models in one wall row keep 0.3 m apart, every item has a sign, and
## no two meshes z-fight. Loads the showroom scene alone (the hub's own suites cover passages,
## navigation and the hub's CSG faces).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SHOWROOM := preload("res://levels/hub/device_showroom.tscn")
const HUB := preload("res://levels/hub/hub.tscn")
## The hub's east wall: interior 30 m wide, so its inner face is at x = 15.
const WALL_X := 15.0
const AREA_Z := 5.5
const AREA_DEPTH := 4.0
const MIN_GAP := 0.3
## How far a wall model's meshes may reach behind the wall's face: the access point's dome rounds
## 2 mm behind its rim (hidden in the wall).
const BEHIND := 0.003

var _showroom: Node3D


func before_test() -> void:
	_showroom = SHOWROOM.instantiate() as Node3D
	add_child(_showroom)
	auto_free(_showroom)


func test_the_hub_holds_the_showroom_against_its_east_wall() -> void:
	var hub := auto_free(HUB.instantiate()) as Node3D
	var room := hub.get_node("Room") as Room

	assert_object(hub.get_node_or_null("DeviceShowroom")).is_not_null()
	assert_float(room.size.x * 0.5).is_equal(WALL_X)


func test_every_model_stands_in_the_showroom_area() -> void:
	var models := _models()
	assert_int(models.size()).is_greater_equal(25)
	for model in models:
		var box := _bounds(model)
		var label := str(_showroom.get_path_to(model))
		assert_float(box.end.x).override_failure_message(label).is_less_equal(WALL_X + BEHIND)
		assert_float(box.position.x).override_failure_message(label).is_greater_equal(WALL_X - AREA_DEPTH)
		assert_float(box.position.z).override_failure_message(label).is_greater_equal(-AREA_Z)
		assert_float(box.end.z).override_failure_message(label).is_less_equal(AREA_Z)


func test_wall_models_sit_on_the_wall_and_keep_apart() -> void:
	var boxes: Array[AABB] = []
	for node in _showroom.get_node("WallGear").get_children():
		var model := node as DeviceModel
		if model == null:
			continue
		var box := _bounds(model)
		if box.position.y < 0.01:
			# Stands on the floor (the turret).
			continue
		assert_float(box.end.x).override_failure_message(model.name).is_between(WALL_X - 0.001, WALL_X + BEHIND)
		boxes.append(box)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a := boxes[i]
			var b := boxes[j]
			if a.position.y > b.end.y or b.position.y > a.end.y:
				continue
			var gap := maxf(b.position.z - a.end.z, a.position.z - b.end.z)
			assert_float(gap).override_failure_message("%s / %s" % [a, b]).is_greater_equal(MIN_GAP)


func test_every_item_has_a_sign() -> void:
	var signs := _showroom.get_node("Signs").get_children()
	var named := 0
	for node in _showroom.get_node("WallGear").get_children() + _showroom.get_node("DeskGear").get_children():
		if node is DeviceModel:
			named += 1
	# One per wall and desk model, the turret's (on its bracket), one per bay, the title.
	assert_int(signs.size()).is_equal(named + 1 + 2 + 1)


func test_no_two_meshes_render_different_materials_on_one_plane() -> void:
	var overlaps := KitGeometry.coplanar_mesh_overlaps(_showroom)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


func _models() -> Array[DeviceModel]:
	var result: Array[DeviceModel] = []
	for node in _showroom.find_children("*", "DeviceModel", true, false):
		result.append(node as DeviceModel)
	return result


# A model's meshes boxed in the showroom's (the hub's) frame.
func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
