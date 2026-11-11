extends Node
## Screenshot helper (not a test, ADR 0113): the deck's screen in the lab fixture (deck_lab.tscn),
## plugged into the wall jack. The shot named by the SHOT environment variable is saved (UI
## included) to SHOT_PATH (default reports/screenshots/deck_<shot>.png), then it quits.
## Shots: map_start (the office subnet and its gateway; nothing behind it), map_hacked (gateway Fw01
## hacked: the security subnet and the second gateway Fw02 show), map_chained (Fw02 hacked too: the
## servers), menu (Advanced: the console's menu with crack time and trace estimates), menu_gateway
## (Master: Fw02's menu with its hidden routes), ice_trained / ice_advanced (the Icebreaker part way
## through the console's Medium password, with that tier's assists), full_trace (the tracer full: the
## address blocked, the incident sent, the console's menu says so).
## It always quits: after saving, on an unknown shot name, and after WATCHDOG real seconds.

const SIZE := Vector2i(1152, 648)
const WATCHDOG := 25.0
const DECK: ItemData = preload("res://items/deck/deck.tres")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const TIERS: Dictionary[String, int] = {
	"map_start": 0,
	"map_hacked": 1,
	"map_chained": 1,
	"menu": 2,
	"menu_gateway": 3,
	"ice_trained": 1,
	"ice_advanced": 2,
	"full_trace": 1,
}

@export var lab_path: NodePath = ^"../DeckLab"

var _lab: Lab
var _player: Player
var _session: DeckSession
var _ice: IcebreakerTool
var _screen: DeckScreen
var _shot: String = ""
var _done: bool = false


func _ready() -> void:
	DisplayServer.window_set_size(SIZE)
	_lab = get_node(lab_path) as Lab
	_player = _lab.get_node("Player") as Player
	_shot = OS.get_environment("SHOT")
	if _shot.is_empty():
		_shot = "map_start"
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(_finish)
	if not TIERS.has(_shot):
		push_error("deck_shots: unknown shot '%s'" % _shot)
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	_session = DeckSession.of(_player)
	_ice = IcebreakerTool.of(_player)
	_screen = DeckScreen.of(_player)
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_player.skills.set_tier(&"computer", TIERS[_shot])
	_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	var jack := _lab.node("Jack").global_position
	var feet := Lab.ORIGIN + Lab.AT_JACK
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := jack - eye
	_player.load_state(
		{"position": feet, "yaw": atan2(-to.x, -to.z), "pitch": -0.35, "crouched": false, "velocity": Vector3.ZERO}
	)
	await _seconds(0.1)
	_session.plug_and_raise(_lab.device("Jack"))
	await _seconds(0.4)
	await _stage()
	await _seconds(0.3)
	_screen.refresh()
	_finish()


func _stage() -> void:
	if _shot != "map_start":
		DeviceAccounts.of(_lab.node("Fw01")).grant(_player, "admin")
	_session.refresh()
	await _seconds(0.4)
	if _shot == "map_chained":
		DeviceAccounts.of(_lab.node("Fw02")).grant(_player, "admin")
		DeviceAccounts.of(_lab.node("OfficePc")).grant(_player, "kbrandt")
		_session.refresh()
		await _seconds(0.4)
	_screen.refresh()
	_screen.graph.fit_view()
	match _shot:
		"menu":
			_screen.graph.select("SEC-CONSOLE")
		"menu_gateway":
			_screen.graph.select("FW-02")
		"ice_trained", "ice_advanced":
			_ice.start(_lab.device("Console"), "dmarsh")
			_ice.job.progress = 0.4
			_screen.show_tool(DeckScreen.Tool.ICEBREAKER)
			await _seconds(0.5)
		"full_trace":
			_ice.start(_lab.device("Console"), "dmarsh")
			_ice.job.progress = 0.6
			await _seconds(0.3)
			_lab.tracer().add(200.0, _player, _session.source)
			await _seconds(0.3)
			_screen.refresh()
			_screen.graph.select("SEC-CONSOLE")


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


# Saves the viewport to SHOT_PATH (default reports/screenshots/deck_<shot>.png) and quits.
func _finish() -> void:
	if _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SHOT_PATH")
	if path.is_empty():
		path = "res://reports/screenshots/deck_%s.png" % _shot
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("deck_shots: could not save %s (%d)" % [path, error])
	get_tree().quit(0 if error == OK else 1)
