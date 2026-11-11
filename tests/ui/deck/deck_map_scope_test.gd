extends GdUnitTestSuite
## Integration (M12b map fix, ADR 0113 amendment): the deck's screen (a DeckScreen on a minimal user
## entity, network_fixtures.gd user()) over two networks with no link between them, the lab (A) and
## the annex (B, network_fixtures.gd annex()). Plugged into A then into B, the Map draws only B
## (its layout checks passed: 0 crossings); unplugged, raised on the Wi-Fi key screen, the Map
## button shows an empty Map with one line (DeckScreen.UNPLUGGED_NOTE).

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const ORIGIN := Vector3(540, 0, -300)
## The user's eye 1 m in front of the lab's jack (0, 0.5, 0) and of the annex's (-4, 0.5, 0).
const AT_A := Vector3(0, 1.6, 1)
const AT_B := Vector3(-4, 1.6, 1)
const ANNEX: Array[String] = ["ANNEX-JACK", "SW-ANNEX", "ANNEX-PC", "PRINTER", "TERMINAL", "AP-ANNEX", "CAM-ANNEX"]

var _a: Dictionary[String, Node3D]
var _b: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession
var _screen: DeckScreen
var _stack: ItemStack


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	_a = Net.lab(root, ORIGIN)
	_b = Net.annex(root, ORIGIN)
	_user = Net.user(root, ORIGIN + AT_A)
	_screen = DeckScreen.new()
	_screen.name = "DeckScreen"
	_user.add_child(_screen)
	_session = DeckSession.of(_user)
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_stack = Net.deck_stack()
	await _frames(2)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	if is_instance_valid(_screen):
		_screen.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Moves the user to `eye`, plugs into `entity` and raises the screen, then waits out the scan.
func _plug(entity: Node3D, eye: Vector3) -> void:
	_user.global_position = ORIGIN + eye
	assert_bool(_session.plug(Device.of(entity), _stack)).is_true()
	_screen.open_for(_session)
	await _frames(15)
	_screen.refresh()


func test_plugged_into_the_second_network_the_map_draws_only_it() -> void:
	await _plug(_a["Jack"], AT_A)
	assert_array(_screen.graph.node_names()).contains(["OFFICE-JACK", "RTR-01"])
	_screen.close()
	await _plug(_b["JackB"], AT_B)
	assert_str(_screen.title_meta.text).is_equal("Plugged into ANNEX-JACK (wall jack) · 10.0.50.40")
	assert_array(_screen.graph.node_names()).contains_exactly_in_any_order(ANNEX)
	assert_bool(_screen.unplugged_label.visible).is_false()
	var rows := _screen.map_rows()
	var result := MapChecks.check(self, rows, MapChecks.cables(rows))
	assert_int(result["crossings"]).is_equal(0)


func test_unplugged_the_map_draws_nothing_and_says_so() -> void:
	await _plug(_b["JackB"], AT_B)
	assert_array(_screen.graph.node_names()).is_not_empty()
	_session.unplug()
	assert_bool(_screen.is_open()).is_false()
	# Raised unplugged on the Wi-Fi key screen; its Map button opens the Map.
	_screen.open_wifi(_session)
	assert_int(_screen.tool).is_equal(DeckScreen.Tool.WIFI)
	assert_bool(_screen.map_button.disabled).is_false()
	assert_bool(_screen.exploits_button.disabled).is_true()
	_screen.map_button.pressed.emit()
	assert_int(_screen.tool).is_equal(DeckScreen.Tool.MAP)
	assert_array(_screen.graph.node_names()).is_empty()
	assert_bool(_screen.unplugged_label.is_visible_in_tree()).is_true()
	assert_str(_screen.unplugged_label.text).is_equal("Plug the deck into a device to see its network.")
	assert_str(_screen.title_meta.text).is_equal("Not plugged in")
	# The deck still remembers the annex.
	assert_array(_stack.state[DeckSession.SEEN] as Array).is_not_empty()
