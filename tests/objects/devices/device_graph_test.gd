extends GdUnitTestSuite
## Unit: DeviceGraph (ADR 0077), the pure reach logic of the cable network. Ids are plain ints;
## the network below is controller 1 - switch 2 - siren 3, plus siren 4 cabled straight to 1 and
## an unlinked device 5.

const CONTROLLER := 1
const SWITCH := 2
const SIREN := 3
const DIRECT_SIREN := 4
const LONER := 5


func _network(switch_up: bool = true) -> DeviceGraph:
	var graph := DeviceGraph.new()
	graph.add_node(CONTROLLER, true)
	graph.add_node(SWITCH, switch_up)
	graph.add_node(SIREN, true)
	graph.add_node(DIRECT_SIREN, true)
	graph.add_node(LONER, true)
	graph.link(CONTROLLER, SWITCH)
	graph.link(SWITCH, SIREN)
	graph.link(DIRECT_SIREN, CONTROLLER)
	return graph


func test_a_direct_link_reaches_both_ways() -> void:
	var graph := _network()
	assert_bool(graph.reaches(CONTROLLER, DIRECT_SIREN)).is_true()
	assert_bool(graph.reaches(DIRECT_SIREN, CONTROLLER)).is_true()


func test_reach_goes_through_an_up_switch() -> void:
	var graph := _network()
	assert_bool(graph.reaches(CONTROLLER, SIREN)).is_true()
	assert_bool(graph.reaches(SIREN, DIRECT_SIREN)).is_true()
	assert_array(Array(graph.reachable(CONTROLLER))).contains_exactly_in_any_order([SWITCH, SIREN, DIRECT_SIREN])


func test_a_down_switch_cuts_everything_behind_it() -> void:
	# Unpowered or broken: the Device reports it as down either way.
	var graph := _network(false)
	assert_bool(graph.reaches(CONTROLLER, SIREN)).is_false()
	assert_bool(graph.reaches(CONTROLLER, SWITCH)).is_false()
	# The direct cable does not go through the switch.
	assert_bool(graph.reaches(CONTROLLER, DIRECT_SIREN)).is_true()
	assert_array(Array(graph.reachable(CONTROLLER))).contains_exactly([DIRECT_SIREN])


func test_down_ends_reach_nothing() -> void:
	var graph := _network()
	graph.add_node(SIREN, false)
	assert_bool(graph.reaches(CONTROLLER, SIREN)).is_false()
	graph.add_node(CONTROLLER, false)
	assert_bool(graph.reaches(CONTROLLER, DIRECT_SIREN)).is_false()
	assert_array(Array(graph.reachable(CONTROLLER))).is_empty()


func test_no_path_means_no_reach() -> void:
	var graph := _network()
	assert_bool(graph.reaches(CONTROLLER, LONER)).is_false()
	assert_bool(graph.reaches(LONER, SIREN)).is_false()
	assert_bool(graph.reaches(CONTROLLER, 99)).is_false()


func test_an_up_node_reaches_itself_and_links_are_not_duplicated() -> void:
	var graph := _network()
	graph.link(CONTROLLER, SWITCH)
	graph.link(SWITCH, CONTROLLER)
	graph.link(CONTROLLER, CONTROLLER)
	assert_bool(graph.reaches(LONER, LONER)).is_true()
	assert_int(graph.reachable(CONTROLLER).size()).is_equal(3)


func test_a_node_linked_before_it_is_added_counts_as_down_until_then() -> void:
	var graph := DeviceGraph.new()
	graph.add_node(CONTROLLER, true)
	graph.link(CONTROLLER, SWITCH)
	graph.link(SWITCH, SIREN)
	graph.add_node(SIREN, true)
	assert_bool(graph.reaches(CONTROLLER, SIREN)).is_false()
	graph.add_node(SWITCH, true)
	assert_bool(graph.reaches(CONTROLLER, SIREN)).is_true()


func test_connected_adds_the_dead_devices_right_behind_live_ones() -> void:
	# The siren dead behind an up switch: not reached, but connected (a terminal shows it as down).
	var graph := _network()
	graph.add_node(SIREN, false)
	assert_array(Array(graph.reachable(CONTROLLER))).contains_exactly_in_any_order([SWITCH, DIRECT_SIREN])
	assert_array(Array(graph.connected(CONTROLLER))).contains_exactly_in_any_order([SWITCH, SIREN, DIRECT_SIREN])


func test_connected_stops_at_a_dead_switch() -> void:
	# The dead switch shows; what is behind it does not.
	var graph := _network(false)
	assert_array(Array(graph.connected(CONTROLLER))).contains_exactly_in_any_order([SWITCH, DIRECT_SIREN])
	assert_array(Array(graph.connected(LONER))).is_empty()
	graph.add_node(CONTROLLER, false)
	assert_array(Array(graph.connected(CONTROLLER))).is_empty()
