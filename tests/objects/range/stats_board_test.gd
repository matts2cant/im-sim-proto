extends GdUnitTestSuite
## StatsBoard (ADR 0125) from scripted shots: `damage` ray stimuli at a minimal box target (not a
## dummy) count as hits at their point in the target's frame, misses passing near it count against
## it, far misses and other stimuli do not count, one line with several damage rays is one shot,
## and reset() clears the board.

const BOARD: PackedScene = preload("res://objects/range/stats_board.tscn")
## The target's feet; its box is 0.6 x 1.8 x 0.3 m, standing on them.
const TARGET := Vector3(-320, 0, 300)
const SHOOTER := Vector3(-320, 1.2, 310)

var _root: Node3D
var _board: StatsBoard
var _target: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_target = StaticBody3D.new()
	_target.name = "Target"
	_target.position = TARGET
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.8, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	_target.add_child(collision)
	_root.add_child(_target)
	_board = BOARD.instantiate() as StatsBoard
	_board.targets = {NodePath("../Target"): "box"}
	_board.window = 10
	_root.add_child(_board)


func test_hits_and_near_misses_give_share_and_group() -> void:
	await _frames(2)
	# Four hits on the front face, 0.2 m apart sideways and up: group 0.28 m.
	for offset: Vector2 in [Vector2(-0.1, 1.1), Vector2(0.1, 1.1), Vector2(-0.1, 1.3), Vector2(0.1, 1.3)]:
		_shoot_at(Vector3(offset.x, offset.y, 0))
	# A miss 0.8 m to the side of the box's centre line (0.5 m clear of its edge).
	_shoot_at(Vector3(0.8, 1.2, 0))
	await _frames(3)

	var stats := _board.stats
	assert_int(stats.shots(&"Target")).is_equal(5)
	assert_int(stats.hits(&"Target")).is_equal(4)
	assert_float(stats.hit_share(&"Target")).is_equal_approx(0.8, 0.0001)
	assert_float(stats.group_size(&"Target")).is_equal_approx(sqrt(0.08), 0.001)
	_board.refresh()
	assert_str(_board.text_label.text).contains("4/5").contains("80 %").contains("28 cm")


func test_far_misses_and_other_stimuli_do_not_count() -> void:
	await _frames(2)
	_shoot_at(Vector3(4.0, 1.2, 0))
	StimulusSystem.emit(Stimulus.make_ray(&"force.impact", 3.0, _from(Vector3(0, 1.2, 0)), Vector3.FORWARD, 30.0))
	StimulusSystem.emit(Stimulus.make_radius(&"damage.fire", 5.0, TARGET + Vector3.UP, 2.0))
	await _frames(3)

	assert_int(_board.stats.shots(&"Target")).is_equal(0)


func test_one_line_with_two_damage_rays_is_one_shot() -> void:
	await _frames(2)
	var origin := _from(Vector3(0, 1.2, 0))
	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 10.0, origin, Vector3.FORWARD, 30.0))
	StimulusSystem.emit(Stimulus.make_ray(&"damage.blunt", 5.0, origin, Vector3.FORWARD, 30.0))
	await _frames(3)

	assert_int(_board.stats.shots(&"Target")).is_equal(1)


func test_reset_clears_the_board() -> void:
	await _frames(2)
	_shoot_at(Vector3(0, 1.2, 0))
	await _frames(3)

	_board.reset()

	assert_int(_board.stats.shots(&"Target")).is_equal(0)
	assert_str(_board.text_label.text).contains("0/0")


func _shoot_at(local: Vector3) -> void:
	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 10.0, _from(local), Vector3.FORWARD, 30.0))


# Shots fly straight down the range (-Z) from the shooter's distance, lined up on `local` (target
# frame).
func _from(local: Vector3) -> Vector3:
	return Vector3(TARGET.x + local.x, TARGET.y + local.y, SHOOTER.z)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
