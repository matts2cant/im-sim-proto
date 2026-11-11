extends GdUnitTestSuite
## Unit (ADR 0113): DeviceGraph's subnets and gates. Ids are plain ints:
##   A1 - S1 - G - S2 - B1      (S1, A1 on subnet a; S2, B1 on subnet b; G a gate on a)
##              \
##               S3 - C1        (subnet c, behind the same gate)
## The gate lets traffic through only for the (from, to) pairs a test allows.

const A1 := 1
const S1 := 2
const G := 3
const S2 := 4
const B1 := 5
const S3 := 6
const C1 := 7

var _allowed: Array[Vector2i] = []


func before_test() -> void:
	_allowed.clear()


func _network() -> DeviceGraph:
	var graph := DeviceGraph.new()
	for id: int in [A1, S1, G, S2, B1, S3, C1]:
		graph.add_node(id, true)
	for pair: Vector2i in [
		Vector2i(A1, S1), Vector2i(S1, G), Vector2i(G, S2), Vector2i(S2, B1), Vector2i(G, S3), Vector2i(S3, C1)
	]:
		graph.link(pair.x, pair.y)
	for id: int in [A1, S1, G]:
		graph.set_subnet(id, &"a")
	for id: int in [S2, B1]:
		graph.set_subnet(id, &"b")
	for id: int in [S3, C1]:
		graph.set_subnet(id, &"c")
	graph.set_gate(G, func(from: int, to: int) -> bool: return _allowed.has(Vector2i(from, to)))
	return graph


func test_a_closed_gate_is_reached_but_not_crossed() -> void:
	var graph := _network()
	assert_bool(graph.reaches(A1, G)).is_true()
	assert_bool(graph.reaches(A1, B1)).is_false()
	assert_bool(graph.reaches(A1, S2)).is_false()
	assert_array(Array(graph.reachable(A1))).contains_exactly_in_any_order([S1, G])


func test_the_gate_decides_per_source_and_destination() -> void:
	var graph := _network()
	_allowed.append(Vector2i(A1, B1))
	assert_bool(graph.reaches(A1, B1)).is_true()
	# The switch on the way is not the destination: no pass for it.
	assert_bool(graph.reaches(A1, S2)).is_false()
	assert_bool(graph.reaches(A1, C1)).is_false()
	assert_bool(graph.reaches(S1, B1)).is_false()
	assert_array(Array(graph.reachable(A1))).contains_exactly_in_any_order([S1, G, B1])


func test_the_gate_sends_and_receives_freely() -> void:
	var graph := _network()
	# Traffic starting at the gate does not cross it.
	assert_bool(graph.reaches(G, B1)).is_true()
	assert_bool(graph.reaches(G, C1)).is_true()
	# From behind it, the gate itself is reached.
	assert_bool(graph.reaches(B1, G)).is_true()
	assert_bool(graph.reaches(B1, A1)).is_false()


func test_leaving_on_the_side_it_came_from_is_free() -> void:
	var graph := _network()
	# A second subnet-a device cabled straight to the gate.
	graph.add_node(10, true)
	graph.set_subnet(10, &"a")
	graph.link(G, 10)
	assert_bool(graph.reaches(A1, 10)).is_true()


func test_without_gates_nothing_changes() -> void:
	var graph := _network()
	graph = DeviceGraph.new()
	for id: int in [A1, S1, G, S2, B1]:
		graph.add_node(id, true)
	graph.link(A1, S1)
	graph.link(S1, G)
	graph.link(G, S2)
	graph.link(S2, B1)
	graph.set_subnet(B1, &"b")
	assert_bool(graph.has_gates()).is_false()
	assert_bool(graph.reaches(A1, B1)).is_true()
	assert_array(Array(graph.reachable(A1))).is_equal([S1, G, S2, B1])


func test_connected_shows_dead_devices_only_through_an_open_gate() -> void:
	var graph := _network()
	graph.add_node(B1, false)
	assert_array(Array(graph.connected(A1))).contains_exactly_in_any_order([S1, G])
	_allowed.append(Vector2i(A1, S2))
	_allowed.append(Vector2i(A1, B1))
	assert_array(Array(graph.connected(A1))).contains_exactly_in_any_order([S1, G, S2, B1])
	# A dead device right behind a closed gate stays hidden.
	_allowed.clear()
	graph.add_node(S3, false)
	assert_bool(Array(graph.connected(A1)).has(S3)).is_false()
