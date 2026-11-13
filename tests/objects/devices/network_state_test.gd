extends GdUnitTestSuite
## NetworkState (ADR 0122, ADR 0130): the one network-state rule the status lights, the interaction
## frame and the deck Map read, on minimal entities (network_fixtures.body_device).
##   Gear (network gear) ── Leaf;  Pair: A ── B (no gear);  Lone (no cables)

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(-640, 0, -640)

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_n.clear()
	var i := 0
	for entity_name: String in ["Gear", "Leaf", "A", "B", "Lone"]:
		_n[entity_name] = Net.body_device(_root, entity_name, ORIGIN + Vector3(i * 2, 1, 0), [], true, 10.0)
		i += 1
	ActorState.set_tag(_n["Gear"], DeviceNetwork.NETWORK_GEAR, true)
	Net.link(_n["Leaf"], _n["Gear"])
	Net.link(_n["A"], _n["B"])


func after_test() -> void:
	StimulusSystem.clear()


func test_links_are_cables_both_ways() -> void:
	assert_array(NetworkState.links_of(_dev("Gear"))).contains_exactly([_dev("Leaf")])
	assert_array(NetworkState.links_of(_dev("Leaf"))).contains_exactly([_dev("Gear")])
	assert_array(NetworkState.links_of(_dev("Lone"))).is_empty()
	assert_bool(NetworkState.is_networked(_dev("Lone"), [])).is_false()
	assert_bool(NetworkState.is_networked(_dev("A"), NetworkState.links_of(_dev("A")))).is_true()


func test_a_leaf_is_cut_off_when_its_gear_is_down_and_a_pair_when_its_peer_is() -> void:
	assert_int(_state("Leaf")).is_equal(StatusLight.State.UP)
	_power("Gear", false)
	assert_int(_state("Leaf")).is_equal(StatusLight.State.CUT_OFF)
	assert_int(_state("A")).is_equal(StatusLight.State.UP)
	_power("B", false)
	assert_int(_state("A")).is_equal(StatusLight.State.CUT_OFF)
	assert_int(_state("Lone")).is_equal(StatusLight.State.UP)


func test_unpowered_is_dark_and_broken_is_disabled() -> void:
	Breakable.of(_n["Leaf"]).take_damage(&"ballistic", 100.0)
	assert_int(_state("Leaf")).is_equal(StatusLight.State.DISABLED)
	_power("Leaf", false)
	assert_int(_state("Leaf")).is_equal(StatusLight.State.DARK)
	assert_int(NetworkState.state_of(null, [])).is_equal(StatusLight.State.DARK)


func test_the_light_and_the_frame_read_the_same_rule() -> void:
	_power("Gear", false)
	await get_tree().process_frame

	var links := NetworkState.links_of(_dev("Leaf"))
	assert_int(StatusLight.of(_n["Leaf"]).state).is_equal(NetworkState.state_of(_dev("Leaf"), links))
	assert_int(TargetStatus.word_of(_n["Leaf"], links)).is_equal(TargetStatus.Word.CUT_OFF)


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _state(entity_name: String) -> StatusLight.State:
	return NetworkState.state_of(_dev(entity_name), NetworkState.links_of(_dev(entity_name)))


func _power(entity_name: String, on: bool) -> void:
	(_n[entity_name].get_node("Powered") as Powered).on = on
