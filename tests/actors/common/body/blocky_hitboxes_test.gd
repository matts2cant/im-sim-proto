extends GdUnitTestSuite
## Unit (ADR 0105): the blocky characters' head hit zone is a box matching the model's head at rest
## (the 0.66-scaled Kenney head: a 0.528 m cube, y 1.254-1.782 m, centred on the body's axis),
## measured from the model's own mesh, not typed in; the player's hitboxes keep the 0.14 m sphere.
## Every guard and the training dummy use these hitboxes.

const BLOCKY: PackedScene = preload("res://actors/common/body/blocky_hitboxes.tscn")
const HUMAN: PackedScene = preload("res://actors/common/body/hitboxes.tscn")
const MODELS: Array[String] = [
	"res://assets/models/kenney_blocky_characters/character-j.glb",
	"res://assets/models/kenney_blocky_characters/character-d.glb",
]
const MODEL_SCALE: float = 0.66
const USERS: Array[String] = [
	"res://actors/guard/guard.tscn", "res://actors/guard/guard_pistol.tscn", "res://actors/dummy/training_dummy.tscn"
]


func test_the_head_box_matches_the_model_head() -> void:
	var hitboxes := auto_free(BLOCKY.instantiate()) as Hitboxes
	var head := hitboxes.get_node("Head") as Node3D
	var shape := (head.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	assert_object(shape).is_not_null()
	var zone := AABB(head.position - shape.size * 0.5, shape.size)
	for model_path in MODELS:
		var head_box := _model_head(model_path)
		# A 0.53 m cube around 1.52 m.
		assert_float(head_box.size.x).is_equal_approx(0.528, 0.005)
		assert_float(head_box.get_center().y).is_equal_approx(1.518, 0.005)
		for axis in 3:
			assert_float(zone.position[axis]).override_failure_message(model_path).is_equal_approx(
				head_box.position[axis], 0.01
			)
			assert_float(zone.end[axis]).override_failure_message(model_path).is_equal_approx(head_box.end[axis], 0.01)
	# The body-part names and the other zones are unchanged: only the head's shape and height.
	assert_str(String(Hitboxes.part_of(head))).is_equal("head")
	assert_int(hitboxes.boxes().size()).is_equal(6)


func test_the_player_keeps_the_head_sphere() -> void:
	var hitboxes := auto_free(HUMAN.instantiate()) as Hitboxes
	var shape := (hitboxes.get_node("Head/Shape") as CollisionShape3D).shape
	assert_bool(shape is SphereShape3D).is_true()
	assert_float((shape as SphereShape3D).radius).is_equal_approx(0.14, 0.001)


func test_guards_and_dummies_use_the_blocky_hitboxes() -> void:
	for scene_path in USERS:
		var entity := auto_free((load(scene_path) as PackedScene).instantiate()) as Node
		var hitboxes := Hitboxes.of(entity)
		assert_str(hitboxes.scene_file_path).override_failure_message(scene_path).is_equal(BLOCKY.resource_path)


# The model's head mesh box in the character's frame (feet at the origin, the model scaled 0.66;
# its 180-degree turn does not change a box centred on the axis).
func _model_head(model_path: String) -> AABB:
	var model := auto_free((load(model_path) as PackedScene).instantiate()) as Node3D
	var mesh := model.find_child("head", true, false) as MeshInstance3D
	var to_model := Transform3D.IDENTITY
	var node: Node = mesh
	while node != model:
		to_model = (node as Node3D).transform * to_model
		node = node.get_parent()
	return (Transform3D(Basis.from_scale(Vector3.ONE * MODEL_SCALE), Vector3.ZERO) * to_model) * mesh.get_aabb()
