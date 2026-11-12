extends GdUnitTestSuite
## Shuttle (ADR 0125): moves its entity back and forth along a line at a steady speed, turning at
## both ends, and stops while the entity cannot act (`state.dead`, `state.unconscious`). Tested on a
## minimal Node3D entity with Tags.

const ORIGIN := Vector3(-300, 0, 320)

var _root: Node3D
var _entity: Node3D
var _tags: Tags
var _shuttle: Shuttle


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)
	_entity = Node3D.new()
	_entity.name = "Walker"
	_entity.position = ORIGIN
	_tags = Tags.new()
	_tags.name = "Tags"
	_entity.add_child(_tags)
	_shuttle = Shuttle.new()
	_shuttle.travel = 4.0
	_shuttle.speed = 1.5
	_entity.add_child(_shuttle)
	_root.add_child(_entity)


func test_walks_to_one_end_turns_and_comes_back() -> void:
	# 1.5 m/s on a 4 m line centred on the start: the end (2 m) after 1.33 s, then back.
	_shuttle.step(1.0)
	assert_float(_entity.position.x - ORIGIN.x).is_equal_approx(1.5, 0.0001)
	_shuttle.step(1.0)
	assert_float(_entity.position.x - ORIGIN.x).is_equal_approx(1.0, 0.0001)
	assert_float(_shuttle.direction).is_equal(-1.0)
	_shuttle.step(2.0)
	assert_float(_entity.position.x - ORIGIN.x).is_equal_approx(-2.0, 0.0001)


func test_covers_the_whole_line_and_never_leaves_it() -> void:
	var lowest := INF
	var highest := -INF
	for i in 600:
		_shuttle.step(1.0 / 60.0)
		var x := _entity.position.x - ORIGIN.x
		lowest = minf(lowest, x)
		highest = maxf(highest, x)
		assert_float(_entity.position.z).is_equal(ORIGIN.z)

	assert_float(highest - lowest).is_equal_approx(4.0, 0.03)
	assert_float(highest).is_less_equal(2.0)
	assert_float(lowest).is_greater_equal(-2.0)


func test_moves_in_the_tree_and_stops_while_down() -> void:
	var start := _entity.position.x
	for i in 30:
		await get_tree().physics_frame
	var moved := _entity.position.x - start
	# Half a second at 1.5 m/s (frames at the runner's fixed rate).
	var expected := 1.5 * 30.0 / Engine.physics_ticks_per_second
	assert_float(moved).is_equal_approx(expected, 0.05)

	_tags.add(ActorState.DEAD)
	var stopped_at := _entity.position
	for i in 30:
		await get_tree().physics_frame
	assert_vector(_entity.position).is_equal(stopped_at)

	_tags.remove(ActorState.DEAD)
	for i in 10:
		await get_tree().physics_frame
	assert_float(_entity.position.x).is_greater(stopped_at.x)


func test_saves_where_it_is_and_which_way_it_goes() -> void:
	_shuttle.step(2.0)
	var saved := _shuttle.save_state()
	_shuttle.step(0.5)

	_shuttle.load_state(saved)

	assert_float(_entity.position.x - ORIGIN.x).is_equal_approx(1.0, 0.0001)
	assert_float(_shuttle.direction).is_equal(-1.0)
