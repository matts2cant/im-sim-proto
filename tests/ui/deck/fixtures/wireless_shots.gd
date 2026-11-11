extends Node
## Screenshot helper (not a test, M12b, ADR 0117): wireless on the deck in the lab fixture
## (deck_lab.tscn) with the access point AP-YARD, its wireless camera and laser and a cabled camera
## beside it (network_fixtures.gd add_wireless()). The shot named by the SHOT environment variable
## is saved (UI included) to SHOT_PATH (default reports/screenshots/wifi_<shot>.png), then it quits.
## Shots: map (Master, on the office wall jack, RTR-01 hacked: AP-YARD and its dashed light-blue
## wireless links on the Map), crack (Trained, aimed at AP-YARD from 6 m: the Wi-Fi key screen part
## way through the crack), paused (a wall cuts the line of sight: "Paused: line of sight lost"),
## joined (the key cracked: joined the security subnet over Wi-Fi), joined_map (the Map from the
## Wi-Fi entry point), world (first person at eye height, the access point on its pole, no screen).
## It always quits: after saving, on an unknown shot name, and after WATCHDOG real seconds.

const SIZE := Vector2i(1152, 648)
const WATCHDOG := 25.0
const DECK: ItemData = preload("res://items/deck/deck.tres")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const TIERS: Dictionary[String, int] = {
	"map": 3,
	"crack": 1,
	"paused": 1,
	"joined": 1,
	"joined_map": 1,
	"world": 1,
}
## South of AP-YARD (12, 2.6, 3): the eye about 6 m from it.
const AIM_FEET := Vector3(12, 0, 9)

@export var lab_path: NodePath = ^"../DeckLab"

var _lab: Lab
var _player: Player
var _session: DeckSession
var _wireless: WirelessTool
var _screen: DeckScreen
var _shot: String = ""
var _done: bool = false


func _ready() -> void:
	DisplayServer.window_set_size(SIZE)
	_lab = get_node(lab_path) as Lab
	_player = _lab.get_node("Player") as Player
	_shot = OS.get_environment("SHOT")
	if _shot.is_empty():
		_shot = "map"
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(_finish)
	if not TIERS.has(_shot):
		push_error("wireless_shots: unknown shot '%s'" % _shot)
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	Net.add_wireless(_lab.network, _lab, Lab.ORIGIN)
	_session = DeckSession.of(_player)
	_wireless = WirelessTool.of(_player)
	_screen = DeckScreen.of(_player)
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_player.skills.set_tier(&"computer", TIERS[_shot])
	_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	await _seconds(0.1)
	await _stage()
	await _seconds(0.3)
	if _screen.is_open():
		_screen.refresh()
	_finish()


func _stage() -> void:
	if _shot == "map":
		_stand(Lab.ORIGIN + Lab.AT_JACK, _lab.node("Jack").global_position, -0.35)
		await _seconds(0.1)
		DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
		_session.plug_and_raise(_lab.device("Jack"))
		await _seconds(0.5)
		_screen.refresh()
		_screen.graph.fit_view()
		_screen.graph.select("CAM-YARD")
		return
	var ap := _lab.node("ApYard").global_position
	if _shot == "world":
		_stand(Lab.ORIGIN + Vector3(11.2, 0, 4.4), ap)
		await _seconds(0.1)
		return
	_stand(Lab.ORIGIN + AIM_FEET, ap)
	await _seconds(0.1)
	_wireless.aim(_lab.device("ApYard"))
	_wireless.start()
	await _seconds(0.2)
	_wireless.job.progress = 0.42
	match _shot:
		"paused":
			_wall()
			await _seconds(0.3)
		"joined", "joined_map":
			_wireless.job.progress = 0.98
			await _seconds(0.5)
			if _shot == "joined_map":
				_screen.show_tool(DeckScreen.Tool.MAP)
				await _seconds(0.4)
				_screen.refresh()
				_screen.graph.fit_view()


func _stand(feet: Vector3, target: Vector3, pitch: float = INF) -> void:
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := target - eye
	var look := atan2(to.y, Vector2(to.x, to.z).length()) if pitch == INF else pitch
	_player.load_state(
		{"position": feet, "yaw": atan2(-to.x, -to.z), "pitch": look, "crouched": false, "velocity": Vector3.ZERO}
	)


# A wall between the player and the access point (cuts the line of sight).
func _wall() -> void:
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.size = Vector3(3, 3, 0.2)
	_lab.add_child(wall)
	wall.global_position = Lab.ORIGIN + Vector3(12, 1.5, 6)


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


# Saves the viewport to SHOT_PATH (default reports/screenshots/wifi_<shot>.png) and quits.
func _finish() -> void:
	if _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SHOT_PATH")
	if path.is_empty():
		path = "res://reports/screenshots/wifi_%s.png" % _shot
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("wireless_shots: could not save %s (%d)" % [path, error])
	get_tree().quit(0 if error == OK else 1)
