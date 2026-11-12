extends GdUnitTestSuite
## Integration (M12c readability, ADR 0122): the HUD's line after a network drop (NetworkFeedback,
## NetworkDrops) with the real Player in the deck lab fixture, on small networks built from components
## near the player (about 10 m) and far from it (about 80 m):
##   Core (gear) ── Up1, Up2          the network that stays
##     └── Switch (gear, breakable) ── A, B, C
## Breaking the near switch shows "SW-T down: 3 devices offline (..)"; the far one shows nothing
## unless the player caused it (a breaker the player switched off in the same tick).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"
const NEAR := Lab.ORIGIN + Vector3(-8, 1, 10)
const FAR := Lab.ORIGIN + Vector3(-80, 1, 10)

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _player: Player
var _feedback: NetworkFeedback
var _root: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_runner = scene_runner(LAB)
	_driver = PlayerDriver.new(_runner)
	_player = _driver.player
	_player.reload_on_reset = false
	_feedback = _player.get_node("Hud/NetworkFeedback") as NetworkFeedback
	_root = Node3D.new()
	_runner.scene().add_child(_root)
	await _driver.frames(NetworkFeedback.SETTLE_FRAMES + 2)


func after_test() -> void:
	StimulusSystem.clear()


# The network of the class description at `at`; returns its entities by name.
func _network(at: Vector3, prefix: String) -> Dictionary[String, Node3D]:
	var n: Dictionary[String, Node3D] = {}
	n["Core"] = Net.body_device(_root, prefix + "Core", at, [], true)
	n["Switch"] = Net.body_device(_root, prefix + "Switch", at + Vector3(2, 0, 0), [], true, 10.0)
	for gear: String in ["Core", "Switch"]:
		ActorState.set_tag(n[gear], DeviceNetwork.NETWORK_GEAR, true)
	for leaf: String in ["Up1", "Up2"]:
		n[leaf] = Net.body_device(_root, prefix + leaf, at + Vector3(0, 0, 1 + n.size()))
		Net.link(n[leaf], n["Core"])
	for leaf: String in ["A", "B", "C"]:
		n[leaf] = Net.body_device(_root, prefix + leaf, at + Vector3(2, 0, 1 + n.size()))
		Net.link(n[leaf], n["Switch"])
	Net.link(n["Switch"], n["Core"])
	n["Switch"].set_meta(&"display_name", "SW-T")
	for leaf: String in ["A", "B", "C"]:
		n[leaf].set_meta(&"display_name", leaf)
	return n


func _names(devices: Array[Device]) -> Array[String]:
	var names: Array[String] = []
	for device in devices:
		names.append(NetworkSource.display_name(device))
	return names


func test_breaking_a_near_switch_names_the_devices_it_took_offline() -> void:
	var n := _network(NEAR, "Near")
	await _driver.frames(1)
	Breakable.of(n["Switch"]).take_damage(&"ballistic", 100.0)
	assert_array(_names(NetworkDrops.offline_after(Device.of(n["Switch"])))).contains_exactly_in_any_order(
		["A", "B", "C"]
	)
	await _driver.frames(2)
	assert_str(_feedback.last_line).starts_with("SW-T down: 3 devices offline (")
	assert_str(_feedback.last_line).ends_with(", +1)")
	assert_str(_feedback.hud.message_label.text).is_equal(_feedback.last_line)


func test_a_far_drop_not_caused_by_the_player_shows_nothing() -> void:
	var n := _network(FAR, "Far")
	await _driver.frames(1)
	Breakable.of(n["Switch"]).take_damage(&"ballistic", 100.0)
	await _driver.frames(2)
	assert_str(_feedback.last_line).is_empty()
	assert_str(_feedback.hud.message_label.text).not_contains("down:")


func test_a_far_drop_from_a_breaker_the_player_switched_shows_the_line() -> void:
	var n := _network(FAR, "Far")
	await _driver.frames(1)
	# What a CircuitBreaker does when the player uses it: the circuit drops, then the switch is logged.
	(n["Switch"].get_node("Powered") as Powered).on = false
	EventLog.record(&"power.switched", String(_player.name), "Breaker", {"circuit": &"test", "on": false})
	await _driver.frames(2)
	assert_str(_feedback.last_line).starts_with("SW-T down: 3 devices offline (")


func test_a_leaf_dropping_takes_nothing_offline() -> void:
	var n := _network(NEAR, "Leaf")
	await _driver.frames(1)
	assert_array(NetworkDrops.offline_after(Device.of(n["A"]))).is_empty()
	var none: Array[String] = []
	assert_str(NetworkDrops.line("A", none)).is_empty()
	var one: Array[String] = ["CAM"]
	assert_str(NetworkDrops.line("SW", one)).is_equal("SW down: 1 device offline (CAM)")
