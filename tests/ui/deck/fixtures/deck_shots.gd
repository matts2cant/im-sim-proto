extends Node
## Screenshot helper (not a test, ADR 0113): the deck's screen in the lab fixture (deck_lab.tscn),
## plugged into the wall jack. The shot named by the SHOT environment variable is saved (UI
## included) to SHOT_PATH (default reports/screenshots/deck_<shot>.png), then it quits.
## Shots: map_start (the office subnet and its router; nothing behind it), map_hacked (router Rtr01
## hacked: the security subnet and the second router Rtr02 show), map_chained (Rtr02 hacked too: the
## servers), menu (Advanced: the console's menu with crack time and trace estimates), menu_router
## (Master: Rtr02's menu with its hidden routes), ice_trained / ice_advanced (the Icebreaker part way
## through the console's Medium password, with that tier's assists), full_trace (the tracer full: the
## address blocked, the incident sent, the console's menu says so), remote (the console's desktop
## opened from the Map over the deck, its Security app on the camera), login_trace (the console
## bare-handed after a wrong password: the tracer's bar in the computer overlay).
## M12b intrusion (ADR 0121): menu_exploit (two camera exploit items carried: CAM-GATE's menu with
## "Use camera exploit (2 left)"), scanning (a router exploit used on RTR-01 from the office jack:
## the Security subnet's scan part way, its dashed box, bar and link), firewall (RTR-01's rules
## with a deny rule selected).
## M12b map fix (ADR 0113 amendment): map_second (RTR-01 hacked on the lab's jack, then plugged into
## a second network with no link to it, network_fixtures.gd annex(), its printer broken: only the
## annex is drawn).
## It always quits: after saving, on an unknown shot name, and after WATCHDOG real seconds.

const SIZE := Vector2i(1152, 648)
const WATCHDOG := 25.0
const DECK: ItemData = preload("res://items/deck/deck.tres")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const TIERS: Dictionary[String, int] = {
	"map_start": 0,
	"map_hacked": 1,
	"map_chained": 1,
	"menu": 2,
	"menu_router": 3,
	"ice_trained": 1,
	"ice_advanced": 2,
	"full_trace": 1,
	"remote": 1,
	"login_trace": 1,
	"menu_exploit": 1,
	"scanning": 1,
	"firewall": 1,
	"map_second": 1,
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
	DisplayServer.window_set_size(shot_size(SIZE))
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


## The window size: SHOT_SIZE ("2560x1440") when set, else `fallback`.
static func shot_size(fallback: Vector2i) -> Vector2i:
	var parts := OS.get_environment("SHOT_SIZE").split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return fallback


func _stage() -> void:
	if _shot not in ["map_start", "scanning"]:
		DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_session.refresh()
	await _seconds(0.4)
	if _shot == "map_chained":
		DeviceAccounts.of(_lab.node("Rtr02")).grant(_player, "admin")
		DeviceAccounts.of(_lab.node("OfficePc")).grant(_player, "kbrandt")
		_session.refresh()
		await _seconds(0.4)
	_screen.refresh()
	_screen.graph.fit_view()
	match _shot:
		"map_second":
			await _plug_second_network()
		"menu_exploit":
			_player.inventory.give(Net.exploit_item(&"camera"), 2)
			_session.refresh()
			_screen.refresh()
			_screen.graph.select("CAM-GATE")
		"scanning":
			_player.inventory.give(Net.exploit_item(&"router"), 1)
			_session.config.scan_time = 3.0
			ExploitItems.use_from_deck(_session, _lab.device("Rtr01"))
			await _seconds(1.0)
			_screen.refresh()
			_screen.graph.fit_view()
		"firewall":
			var router := Router.of(_lab.node("Rtr01"))
			router.add_rule(
				RouterRule.make(RouterRule.Match.SUBNET, "security", RouterRule.Match.SUBNET, "office", true)
			)
			router.add_rule(RouterRule.make(RouterRule.Match.YOU, "", RouterRule.Match.SUBNET, "security", true))
			router.add_rule(
				RouterRule.make(RouterRule.Match.DEVICE, "10.0.20.40", RouterRule.Match.DEVICE, "10.0.10.12", false)
			)
			router.add_rule(
				RouterRule.make(RouterRule.Match.SUBNET, "office", RouterRule.Match.SUBNET, "security", false)
			)
			_screen.firewall_view.show_router(_lab.device("Rtr01"))
			_screen.firewall_view.selected = 2
			_screen.show_tool(DeckScreen.Tool.FIREWALL)
		"remote":
			DeviceAccounts.of(_lab.node("Console")).grant(_player, "dmarsh")
			_session.refresh()
			_session.open_remote(_lab.device("Console"))
			var desktop := ComputerScreen.of(_player)
			desktop.show_app(ComputerScreen.App.SECURITY)
			desktop.security_app.refresh(true)
			desktop.security_app.select("CAM-GATE")
		"login_trace":
			_screen.close()
			_session.unplug()
			var at := Lab.ORIGIN + Vector3(7, 0, 4.2)
			_player.load_state({"position": at, "yaw": 0.0, "pitch": -0.2, "crouched": false, "velocity": Vector3.ZERO})
			await _seconds(0.1)
			var console := Computer.of(_lab.node("Console"))
			console.use_by(_player)
			var screen := ComputerScreen.of(_player)
			screen.user_field.text = "dmarsh"
			screen.password_field.text = "anchor77"
			screen.submit_login()
			_screen.refresh_computer_traces()
		"menu":
			_screen.graph.select("SEC-CONSOLE")
		"menu_router":
			_screen.graph.select("RTR-02")
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


# Unplugs from the lab, builds the annex network beside it and plugs into its jack.
func _plug_second_network() -> void:
	_session.unplug()
	var annex := Net.annex(_lab, Lab.ORIGIN)
	Breakable.of(annex["PrinterB"]).take_damage(&"damage.ballistic", 100.0)
	var feet := Lab.ORIGIN + Vector3(-4, 0, 1.2)
	_player.load_state({"position": feet, "yaw": 0.0, "pitch": -0.35, "crouched": false, "velocity": Vector3.ZERO})
	await _seconds(0.1)
	_session.plug_and_raise(Device.of(annex["JackB"]))
	await _seconds(0.4)
	_screen.refresh()
	_screen.graph.fit_view()


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
