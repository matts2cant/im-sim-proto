extends GdUnitTestSuite
## ImpactMarks + MarkImpactEffect (ADR 0125): any surface entity with the `marked_by_bullets`
## receptron and an ImpactMarks keeps a mark where each `damage.ballistic` ray hit it; marks stay,
## the oldest goes past the cap, clear() removes them. Built on a minimal static box in code (not the
## range's spray wall).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const MARKED: Receptron = preload("res://objects/components/receptrons/marked_by_bullets.tres")
const ORIGIN := Vector3(-300, 1, 300)

var _root: Node3D
var _marks: ImpactMarks


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_marks = ImpactMarks.new()
	_marks.name = "ImpactMarks"
	body.add_child(_marks)
	Fixtures.compose(body, _root, "Board", ORIGIN, [MARKED])


func test_a_bullet_ray_leaves_a_mark_where_it_hit() -> void:
	await Fixtures.frames(get_tree(), 2)

	_shoot(Vector2(0.3, -0.2))
	await Fixtures.frames(get_tree(), 3)

	assert_int(_marks.count()).is_equal(1)
	# On the front face (z + 0.1), at the aimed point.
	assert_vector(_marks.points()[0]).is_equal_approx(ORIGIN + Vector3(0.3, -0.2, 0.1), Vector3.ONE * 0.001)


func test_marks_stay() -> void:
	await Fixtures.frames(get_tree(), 2)
	for i in 3:
		_shoot(Vector2(0.2 * i, 0))
	await Fixtures.frames(get_tree(), 60)

	assert_int(_marks.count()).is_equal(3)


func test_other_rays_leave_nothing() -> void:
	await Fixtures.frames(get_tree(), 2)

	var origin := ORIGIN + Vector3(0, 0, 5)
	StimulusSystem.emit(Stimulus.make_ray(&"force.impact", 3.0, origin, Vector3.FORWARD, 10.0))
	await Fixtures.frames(get_tree(), 3)

	assert_int(_marks.count()).is_equal(0)


func test_past_the_cap_the_oldest_mark_goes() -> void:
	await Fixtures.frames(get_tree(), 1)
	var cap := _marks.max_marks
	for i in cap + 10:
		_marks.add_mark(ORIGIN + Vector3(0.001 * i, 0, 0.1), Vector3.BACK)

	assert_int(cap).is_equal(500)
	assert_int(_marks.count()).is_equal(cap)
	var points := _marks.points()
	# The first ten are gone: the oldest shown is the eleventh, the newest the last one.
	assert_float(points[0].x - ORIGIN.x).is_equal_approx(0.010, 0.0001)
	assert_float(points[-1].x - ORIGIN.x).is_equal_approx(0.001 * (cap + 9), 0.0001)


func test_clear_removes_every_mark() -> void:
	await Fixtures.frames(get_tree(), 1)
	_marks.add_mark(ORIGIN, Vector3.BACK)
	_marks.clear()

	assert_int(_marks.count()).is_equal(0)
	assert_array(_marks.points()).is_empty()


# A pistol-like bullet ray from 5 m in front of the board to `offset` on its face.
func _shoot(offset: Vector2) -> void:
	var origin := ORIGIN + Vector3(offset.x, offset.y, 5)
	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 25.0, origin, Vector3.FORWARD, 10.0))
