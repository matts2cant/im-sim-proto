extends GdUnitTestSuite
## Integration: NavWalker turns to world directions even under a turned parent (a guard in a room
## instanced at 90 or 180 degrees): face_direction() takes a world direction and the walker turns its
## global yaw to it.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const WALKER_CONFIG: NavWalkerConfig = preload("res://actors/guard/guard_walker.tres")


func test_faces_a_world_direction_under_a_turned_parent() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	Characters.floor_box(root)
	var room := Node3D.new()
	room.rotation.y = PI * 0.5
	root.add_child(room)
	var walker := NavWalker.new()
	walker.config = WALKER_CONFIG
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	walker.add_child(shape)
	walker.position = Vector3(0, 0.05, 0)
	room.add_child(walker)
	await Fixtures.frames(get_tree(), 2)

	walker.face_direction(Vector3(1, 0, 0))
	# 240 degrees per second: well within 1.5 s from any start.
	await Fixtures.frames(get_tree(), 90)
	assert_float(walker.facing().dot(Vector3(1, 0, 0))).is_greater(0.999)
