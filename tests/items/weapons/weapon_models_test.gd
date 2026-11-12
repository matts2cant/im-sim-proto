extends GdUnitTestSuite
## Data rule: every held weapon (not melee) shows a model, not the grey box fallback, so a guard or
## the player never holds a box by a missing `view_scene`.

const ROOT := "res://items/weapons"


func test_every_non_melee_weapon_data_has_a_view_scene() -> void:
	var checked := 0
	var missing: Array[String] = []
	for path in _tres_files(ROOT):
		var weapon := load(path) as WeaponData
		if weapon == null:
			continue
		checked += 1
		if not weapon.is_melee() and weapon.view_scene == null:
			missing.append(path)

	assert_int(checked).is_greater(3)
	assert_array(missing).is_empty()


## The muzzle marker (flash, tracers, the silencer's mount) sits at the barrel's end: within
## MUZZLE_GAP of the model's front-most point (-Z), with the barrel right behind it (a ray back
## along +Z meets the model within BARREL_DEPTH: a bore's bottom counts, the sniper's is 6 cm deep).
func test_every_model_muzzle_is_at_its_barrel_end() -> void:
	const MUZZLE_GAP := 0.015
	const BARREL_DEPTH := 0.08
	var checked := 0
	for path in _tres_files(ROOT):
		var weapon := load(path) as WeaponData
		if weapon == null or weapon.is_melee() or weapon.view_scene == null:
			continue
		var model := auto_free(weapon.view_scene.instantiate()) as WeaponModel
		add_child(model)
		if model.muzzle == null:
			continue
		checked += 1
		var faces := _model_faces(model)
		var front := INF
		for point in faces:
			front = minf(front, point.z)
		var surface := TriangleMesh.new()
		surface.create_from_faces(faces)
		var at := model.to_local(model.muzzle.global_position)
		var hit := surface.intersect_ray(at, Vector3.BACK)
		var depth := INF if hit.is_empty() else (hit["position"] as Vector3).z - at.z
		var label := "%s: muzzle %s, front z %.3f, barrel %.3f m behind" % [path, at, front, depth]
		assert_float(absf(at.z - front)).override_failure_message(label).is_less(MUZZLE_GAP)
		assert_float(depth).override_failure_message(label).is_less(BARREL_DEPTH)
	assert_int(checked).is_greater(3)


# Every face (vertex triples) of the model's meshes in its own frame.
func _model_faces(model: WeaponModel) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var place := model.global_transform.affine_inverse() * part.global_transform
		for vertex in part.mesh.get_faces():
			points.append(place * vertex)
	return points


func _tres_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_tres_files(dir_path.path_join(sub)))
	return found
