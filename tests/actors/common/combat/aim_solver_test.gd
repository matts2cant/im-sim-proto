extends GdUnitTestSuite
## Integration (audit Q9): AimSolver, the aim rule guards (CombatBehaviour) and turrets share, on a
## minimal target built from components. A shooter's eye 1.6 m up, 6 m from a target with the
## humanoid hitboxes (torso centre 1.21 m, head 1.64 m): a plate 3 m out spanning 1.35-1.45 m
## blocks the line to the torso (1.405 m there) and the arms (1.39 m) but not the head (1.62 m),
## so the head is chosen; a wall over the whole target leaves the torso, unclear. A target without
## hitboxes gets the three points of its shape. look_at() turns a node's -Z onto a point and leaves
## it alone straight above.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const ORIGIN := Vector3(660, 0, 0)
const EYE := ORIGIN + Vector3(0, 1.6, 0)
const TARGET_FEET := ORIGIN + Vector3(0, 0, -6)

var _root: Node3D
var _target: CharacterBody3D


func before_test() -> void:
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_target = Characters.character(_root, "Target", TARGET_FEET, [] as Array[StringName])
	_target.add_child(HITBOXES.instantiate())
	var ground := Characters.floor_box(_root)
	ground.position += ORIGIN


func test_the_torso_first_when_its_line_is_clear() -> void:
	await _physics(2)
	var choice := AimSolver.choose(_space(), EYE, _target, [] as Array[RID])
	assert_bool(choice.clear).is_true()
	assert_vector(choice.point).is_equal_approx(_box(BodyDamageModel.TORSO), Vector3.ONE * 0.001)


func test_the_head_when_a_plate_covers_the_torso_line() -> void:
	_plate(ORIGIN + Vector3(0, 1.4, -3), Vector3(1.0, 0.1, 0.1))
	await _physics(2)
	var choice := AimSolver.choose(_space(), EYE, _target, [] as Array[RID])
	assert_bool(choice.clear).is_true()
	assert_vector(choice.point).is_equal_approx(_box(BodyDamageModel.HEAD), Vector3.ONE * 0.001)


func test_the_torso_unclear_when_nothing_is_in_sight() -> void:
	_plate(ORIGIN + Vector3(0, 1.0, -3), Vector3(3.0, 3.0, 0.1))
	await _physics(2)
	var choice := AimSolver.choose(_space(), EYE, _target, [] as Array[RID])
	assert_bool(choice.clear).is_false()
	assert_vector(choice.point).is_equal_approx(_box(BodyDamageModel.TORSO), Vector3.ONE * 0.001)


func test_a_target_without_hitboxes_gets_the_points_of_its_shape() -> void:
	var bare := Characters.character(_root, "Bare", ORIGIN + Vector3(3, 0, -6), [] as Array[StringName])
	var points := AimSolver.aim_points(bare)
	assert_int(points.size()).is_equal(3)
	# The chest first, between the feet and the head.
	assert_float(points[0].y).is_between(points[2].y, points[1].y)


func test_look_at_turns_the_node_and_leaves_it_straight_above() -> void:
	var node := Node3D.new()
	_root.add_child(node)
	node.global_position = EYE
	AimSolver.look_at(node, EYE + Vector3(4, 0, 0))
	assert_vector(-node.global_basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
	var before := node.global_basis
	AimSolver.look_at(node, EYE + Vector3(0, 3, 0))
	assert_bool(node.global_basis.is_equal_approx(before)).is_true()


func _plate(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	body.global_position = centre


func _box(part: StringName) -> Vector3:
	return Hitboxes.of(_target).box(part).global_position


func _space() -> PhysicsDirectSpaceState3D:
	return _root.get_world_3d().direct_space_state


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
