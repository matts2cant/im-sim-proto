extends GdUnitTestSuite
## Integration (M12c readability, ADR 0122): the deck's AR cable view (DeckArView) on the real Player
## in the deck lab fixture (tests/ui/deck/fixtures/deck_lab.tscn, the lab network plus AP-YARD and
## its wireless camera). RMB (`alt_fire`) toggles it only while the deck is in hand; putting the deck
## away or opening a screen turns it off. It draws one run per link between seen devices (the held
## deck's SEEN list) within 30 m, coloured from the subnet data, wireless links dashed, down links
## dim; nothing for unseen devices.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"
const OFFICE: Subnet = preload("res://objects/network/subnets/office.tres")

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _view: DeckArView
var _stack: ItemStack


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_runner = scene_runner(LAB)
	_driver = PlayerDriver.new(_runner)
	_lab = _runner.scene() as Lab
	_player = _driver.player
	_player.reload_on_reset = false
	_view = DeckArView.of(_player)
	Net.add_wireless(_lab.network, _lab, Lab.ORIGIN)
	await _driver.settle()
	_player.inventory.give(DECK, 1)
	_stack = _player.inventory.inventory.stacks_of(&"deck")[0]
	_player.inventory.hold(_stack)
	await _driver.frames(2)


func after_test() -> void:
	var session := DeckSession.of(_player)
	if is_instance_valid(session):
		session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _see(names: Array[String]) -> void:
	var paths: Array[String] = []
	for entity_name in names:
		paths.append(String(_lab.node(entity_name).get_path()))
	_stack.state[DeckSession.SEEN] = paths


func _pairs() -> Array[String]:
	var found: Array[String] = []
	for link in _view.drawn:
		var a := String((link["a"] as Device).entity.name)
		var b := String((link["b"] as Device).entity.name)
		found.append("%s-%s" % [a, b] if a < b else "%s-%s" % [b, a])
	return found


func test_rmb_toggles_it_only_with_the_deck_in_hand() -> void:
	_see(["Jack", "OfficeSwitch"])
	await _driver.hold(&"alt_fire", 2)
	assert_bool(_view.active).is_true()
	(_player.get_node("Hud") as Hud).refresh_ar_hint()
	assert_bool((_player.get_node("Hud") as Hud).ar_hint.visible).is_true()
	await _driver.frames(1)
	await _driver.hold(&"alt_fire", 2)
	assert_bool(_view.active).is_false()
	_player.inventory.put_away()
	await _driver.frames(1)
	await _driver.hold(&"alt_fire", 2)
	assert_bool(_view.active).is_false()


func test_putting_the_deck_away_or_opening_a_screen_turns_it_off() -> void:
	assert_bool(_view.toggle()).is_true()
	_player.inventory.put_away()
	await _driver.frames(2)
	assert_bool(_view.active).is_false()
	_player.inventory.hold(_stack)
	await _driver.frames(1)
	assert_bool(_view.toggle()).is_true()
	# LMB on the jack plugs the deck in and raises its screen.
	_player.load_state(Objects.aiming_state(_player, Lab.ORIGIN + Lab.AT_JACK, _lab.node("Jack").global_position))
	await _driver.frames(3)
	await _driver.hold(&"fire", 2)
	await _driver.frames(2)
	assert_bool(DeckScreen.of(_player).is_open()).is_true()
	assert_bool(_view.active).is_false()


func test_draws_one_run_per_seen_link_in_the_subnet_colour() -> void:
	_see(["Jack", "OfficeSwitch", "OfficePc", "Rtr01"])
	assert_bool(_view.toggle()).is_true()
	assert_array(_pairs()).contains_exactly_in_any_order(
		["Jack-OfficeSwitch", "OfficePc-OfficeSwitch", "OfficeSwitch-Rtr01"]
	)
	for link in _view.drawn:
		assert_bool(link["wireless"]).is_false()
		assert_bool(link["up"]).is_true()
		assert_object(link["color"]).is_equal(OFFICE.map_color)
	# Three segments (up, across, down) per run, two vertices each.
	assert_int(_view.vertex_count).is_equal(3 * 3 * 2)


func test_wireless_links_are_dashed_and_down_links_dim() -> void:
	_see(["ApYard", "CamYard", "SecuritySwitch", "OfficeSwitch", "Jack"])
	assert_bool(_view.toggle()).is_true()
	var wireless := _view.drawn.filter(func(link: Dictionary) -> bool: return bool(link["wireless"]))
	assert_int(wireless.size()).is_equal(1)
	assert_object(wireless[0]["color"]).is_equal(DeckArView.WIRELESS_COLOR)
	assert_int(DeckArView.dashes(Vector3.ZERO, Vector3(0, 0, 5)).size()).is_equal(20)
	# OfficeSwitch down: its link to the jack is drawn dim (rebuilt on its state change).
	(_lab.node("OfficeSwitch").get_node("Powered") as Powered).on = false
	var dim := _view.drawn.filter(func(link: Dictionary) -> bool: return not bool(link["up"]))
	assert_int(dim.size()).is_equal(1)


func test_nothing_for_unseen_or_far_devices() -> void:
	var far_a := Net.body_device(_lab, "FarA", Lab.ORIGIN + Vector3(0, 1, 60))
	var far_b := Net.body_device(_lab, "FarB", Lab.ORIGIN + Vector3(3, 1, 60))
	Net.link(far_a, far_b)
	_lab.network["FarA"] = far_a
	_lab.network["FarB"] = far_b
	_see(["Jack", "FarA", "FarB"])
	assert_bool(_view.toggle()).is_true()
	# Jack's switch is unseen, the far pair out of range.
	assert_array(_view.drawn).is_empty()
	assert_int(_view.vertex_count).is_equal(0)


func test_ceiling_run_shape() -> void:
	var run := DeckArView.ceiling_run(Vector3(0, 1, 0), Vector3(4, 2, 0), 3.5)
	assert_array(Array(run)).is_equal([Vector3(0, 1, 0), Vector3(0, 3.5, 0), Vector3(4, 3.5, 0), Vector3(4, 2, 0)])
