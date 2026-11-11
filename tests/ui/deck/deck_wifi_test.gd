extends GdUnitTestSuite
## Integration (M12b, ADR 0115, 0117): wireless on the deck's screens. The Map of the lab network with
## the access point AP-YARD (network_fixtures.gd add_wireless()): its two wireless links drawn dashed
## in the light blue (NetworkGraph.WIRELESS_COLOR), the wireless devices placed with their access
## point, every readability check passed with 0 crossings; a dead access point greys its links. The
## real Player in the lab fixture (fixtures/deck_lab.tscn): LMB with the deck aimed at the access
## point from 6 m raises the Wi-Fi key screen; out of range (Untrained 8 m) only a HUD message; the
## crack pauses on the screen when a wall cuts the line of sight; cracked, the deck joins the
## security subnet and the Map shows it from there.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"
const MAP_ORIGIN := Vector3(380, 0, 420)
## South of the access point (12, 2.6, 3): the eye 6.1 m from it, 8.6 m from it.
const NEAR_FEET := Vector3(12, 0, 9)
const FAR_FEET := Vector3(12, 0, 11.5)


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _names(rows: Array[NetworkRow]) -> Array[String]:
	var found: Array[String] = []
	for row in rows:
		found.append(row.name)
	return found


func test_the_map_draws_wireless_links_dashed_light_blue_without_crossings() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var n := Net.lab(root, MAP_ORIGIN)
	Net.add_wireless(n, root, MAP_ORIGIN)
	await get_tree().physics_frame
	var rows := MapChecks.rows_from(n["Jack"])
	var cables := MapChecks.cables(rows)
	assert_array(_names(rows)).contains(["AP-YARD", "CAM-YARD", "LASER-ROOF", "CAM-DOCK"])
	var result := MapChecks.check(self, rows, cables)
	assert_int(result["crossings"]).is_equal(0)
	assert_int(result["extra"]).is_equal(0)
	# The wireless links: two, from AP-YARD, dashed light blue while live.
	var graph: NetworkGraph = auto_free(NetworkGraph.new())
	add_child(graph)
	graph.size = MapChecks.DECK_MAP_SIZE
	graph.show_network(rows, cables)
	assert_int(graph.wireless.size()).is_equal(2)
	var names := _names(rows)
	var ap := names.find("AP-YARD")
	for k in graph.wireless:
		var cable := cables[k]
		assert_bool(cable.x == ap or cable.y == ap).is_true()
		assert_object(graph.cable_color(k)).is_equal(NetworkGraph.WIRELESS_COLOR)
	# Every other cable stays a green cable.
	for k in cables.size():
		if not graph.wireless.has(k):
			assert_object(graph.cable_color(k)).is_equal(NetworkGraph.LIVE_CABLE_COLOR)
	# The wireless devices sit with their access point: in its group (its comb).
	var layout := graph.layout
	for entity_name: String in ["CAM-YARD", "LASER-ROOF"]:
		var i := names.find(entity_name)
		assert_int(layout.hub_of[i]).override_failure_message(entity_name).is_equal(ap)
	assert_str(rows[ap].role).is_equal("access point")
	# A dead access point: its links grey (still dashed: wireless).
	Powered.of(n["ApYard"]).on = false
	var dead := MapChecks.rows_from(n["Jack"])
	graph.show_network(dead, MapChecks.cables(dead))
	assert_int(graph.wireless.size()).is_equal(2)
	for k in graph.wireless:
		assert_object(graph.cable_color(k)).is_equal(DeckStyle.OFFLINE_COLOR)


func test_aiming_the_deck_at_an_access_point_cracks_its_key_and_joins_its_subnet() -> void:
	var runner := scene_runner(LAB)
	var driver := PlayerDriver.new(runner)
	var lab := runner.scene() as Lab
	var player := driver.player
	player.reload_on_reset = false
	var session := DeckSession.of(player)
	var screen := DeckScreen.of(player)
	var wireless := WirelessTool.of(player)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	Net.add_wireless(lab.network, lab, Lab.ORIGIN)
	await driver.settle()
	player.inventory.give(DECK, 1)
	player.inventory.hold(player.inventory.inventory.stacks_of(&"deck")[0])
	var ap := lab.node("ApYard").global_position
	# Untrained (8 m): from 8.6 m, LMB only says it is out of range.
	player.load_state(Objects.aiming_state(player, Lab.ORIGIN + FAR_FEET, ap))
	await driver.frames(3)
	await driver.hold(&"fire", 2)
	await driver.frames(1)
	assert_bool(screen.is_open()).is_false()
	var hud := player.get_node("Hud") as Hud
	assert_str(hud.message_label.text).contains("out of the deck's Wi-Fi range")
	# From 6.1 m: the Wi-Fi key screen.
	player.load_state(Objects.aiming_state(player, Lab.ORIGIN + NEAR_FEET, ap))
	await driver.frames(3)
	await driver.hold(&"fire", 2)
	await driver.frames(1)
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.tool).is_equal(DeckScreen.Tool.WIFI)
	assert_object(wireless.target).is_same(lab.device("ApYard"))
	assert_str(screen.title_meta.text).is_equal("Aimed at AP-YARD · access point · 6.1 m")
	assert_bool(screen.map_button.disabled).is_true()
	var texts := screen.wifi_view.texts()
	assert_array(texts).contains(["Wi-Fi key · AP-YARD", "Crack the key", "clear"])
	assert_array(texts).contains(["key strength Weak · your range 8 m (Computer skill: Untrained)"])
	screen.find_button("Crack the key").pressed.emit()
	await driver.frames(60)
	assert_bool(wireless.is_running()).is_true()
	assert_float(wireless.job.progress).is_between(0.05, 0.15)
	# A wall drops between the player and the access point: paused, said on the screen.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3, 3, 0.2)
	wall.add_child(shape)
	lab.add_child(wall)
	wall.global_position = Lab.ORIGIN + Vector3(12, 1.5, 6)
	await driver.frames(20)
	screen.refresh()
	assert_array(screen.wifi_view.texts()).contains(["Paused: line of sight lost", "blocked"])
	var paused := wireless.job.progress
	await driver.frames(30)
	assert_float(wireless.job.progress).is_equal_approx(paused, 0.0001)
	wall.free()
	await driver.frames(10)
	wireless.job.progress = 0.97
	await driver.frames(30)
	# Cracked: joined the security subnet over Wi-Fi; the Map from there.
	assert_bool(session.is_wireless()).is_true()
	screen.refresh()
	assert_array(screen.wifi_view.texts()).contains(
		["Key cracked: joined the SECURITY subnet over Wi-Fi (10.0.20.90) while in range", "Map"]
	)
	screen.find_button("Map").pressed.emit()
	await driver.frames(20)
	screen.refresh()
	assert_int(screen.tool).is_equal(DeckScreen.Tool.MAP)
	assert_str(screen.title_meta.text).is_equal("Joined AP-YARD (Wi-Fi) · 10.0.20.90")
	assert_array(screen.graph.node_names()).contains(["AP-YARD", "CAM-YARD", "LASER-ROOF"])
	assert_str(screen.graph.node_button("AP-YARD").text).is_equal("AP-YARD · access point")
	assert_int(screen.graph.wireless.size()).is_equal(2)
	screen.graph.select("CAM-YARD")
	assert_array(screen.menu_texts()).contains(["wireless via AP-YARD"])
	session.unplug()
