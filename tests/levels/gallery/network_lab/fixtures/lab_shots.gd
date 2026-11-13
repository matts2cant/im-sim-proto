extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 8 (network lab) in
## the hub at eye height (1.65 m). Run the scene in a window with `-- shots=<name>,<name> out=<folder>`
## (or `shots=all`): for each shot it places the hub player, waits, saves `<folder>/<name>.png` (HUD
## included) and quits after the last one, or after WATCHDOG real seconds. Positions are lab-local
## (origin on the hub wall, -Z into the lab) unless `space` is "hub". The player loses its
## `actor.player` tag so the camera leaves it alone. Keys: `open` doors (paths under Doors/) opened
## first; `off` circuits switched off; `computer` that computer (a path under Devices/) opened on its
## desktop as its first account, on `app` (security, mail or files) with `select` selected; `deck`
## plugs a deck into that device (a path under Devices/) and raises its Map, `hack` grants those
## routers' first account first, `menu` opens that device's menu (its display name); `wifi` grants
## the access point's key first (the deck joins its Wi-Fi), `aim` aims the deck at it instead and
## starts the crack (the Wi-Fi key screen); `ar` closes the Map and turns the deck's AR cable view on;
## `bays` opens those linking bays' glass doors (paths under Devices/); `jam` starts a jamming field
## there (M14b). States last for the rest of the run: put such shots last.

const SHOT_SIZE := Vector2i(1152, 648)
const WAIT := 1.2
const WATCHDOG := 60.0
const DECK: ItemData = preload("res://items/deck/deck.tres")
const JAMMING_FIELD: PackedScene = preload("res://objects/explosives/jamming_field/jamming_field.tscn")

const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"space": "hub", "feet": Vector3(-9, 0, -2), "look": Vector3(-16, 1.6, -2)},
	"doorway_out": {"feet": Vector3(0, 0, 1.6), "look": Vector3(0.3, 1.5, -4)},
	"doorway_in": {"feet": Vector3(0.6, 0, -5.4), "look": Vector3(0, 1.7, -2)},
	"entrance": {"feet": Vector3(0, 0, -4.6), "look": Vector3(5, 1.0, -14)},
	"entrance_left": {"feet": Vector3(0.4, 0, -4.6), "look": Vector3(-1.5, 1.0, -12)},
	"overview": {"feet": Vector3(11, 0, -4.6), "look": Vector3(2, 0.6, -14)},
	"deck_table": {"feet": Vector3(2.6, 0, -5.9), "look": Vector3(2.6, 1.0, -4.3)},
	"jack": {"feet": Vector3(-0.6, 0, -6), "look": Vector3(-2, 0.6, -6)},
	"office_pc1": {"feet": Vector3(-0.4, 0, -8.5), "look": Vector3(-2, 0.95, -8.5)},
	"office_pc2": {"feet": Vector3(-0.4, 0, -12), "look": Vector3(-2, 0.95, -12)},
	# ADR 0130 step 3: the bays from 1.5 m and their units from 0.5 m, the desk gear.
	"bay_a": {"feet": Vector3(0.1, 0, -15.7), "look": Vector3(-1.7, 1.15, -15.7)},
	"bay_a_units": {"feet": Vector3(-0.95, 0, -15.7), "look": Vector3(-1.45, 1.45, -15.7)},
	"bay_a_blanks": {"feet": Vector3(-0.95, 0, -15.7), "look": Vector3(-1.45, 0.9, -15.7)},
	"bay_a_side": {"feet": Vector3(0.2, 0, -13.6), "look": Vector3(-1.7, 1.4, -15.6)},
	"bay_b": {"feet": Vector3(9.9, 0, -15.7), "look": Vector3(11.4, 1.15, -15.7)},
	"bay_b_open": {"feet": Vector3(9.7, 0, -14.8), "look": Vector3(11.4, 1.2, -15.9), "bays": ["BayB"]},
	"bay_b_units": {"feet": Vector3(10.85, 0, -15.7), "look": Vector3(11.45, 1.4, -15.7), "bays": ["BayB"]},
	"bay_b_lock": {"feet": Vector3(10.6, 0, -15.3), "look": Vector3(11.37, 1.0, -15.45)},
	"bay_c": {"feet": Vector3(13.3, 0, -30.4), "look": Vector3(13.3, 1.15, -32.2)},
	"bay_c_units": {"feet": Vector3(13.3, 0, -31.35), "look": Vector3(13.3, 1.35, -31.95)},
	"desk_gear": {"feet": Vector3(-0.3, 0, -12.4), "look": Vector3(-1.75, 0.85, -12.5)},
	"office_switch_close": {"feet": Vector3(-1.0, 0, -12.7), "look": Vector3(-1.7, 0.77, -12.7)},
	"mail_desk": {"feet": Vector3(10.2, 0, -9.1), "look": Vector3(11.8, 0.9, -9.1)},
	"edge_router_close": {"feet": Vector3(11.1, 0, -8.72), "look": Vector3(11.75, 0.77, -8.72)},
	"rtr01": {"feet": Vector3(0.0, 0, -15.0), "look": Vector3(-2, 1.7, -15.4)},
	"security_corner": {"feet": Vector3(0.6, 0, -15.6), "look": Vector3(0.2, 1.6, -18)},
	"console": {"feet": Vector3(2.6, 0, -16.2), "look": Vector3(2.6, 1.0, -18)},
	"closet_door": {"feet": Vector3(5.85, 0, -15.6), "look": Vector3(5.85, 1.8, -18.25)},
	"closet_open": {"feet": Vector3(5.85, 0, -16.6), "look": Vector3(6, 0.9, -20.7), "open": ["ClosetDoor"]},
	"closet_inside": {"feet": Vector3(6.4, 0, -20.2), "look": Vector3(5.6, 1.5, -17.5), "open": ["ClosetDoor"]},
	"closet_shelf": {"feet": Vector3(6.0, 0, -19.2), "look": Vector3(6.0, 0.8, -20.7), "open": ["ClosetDoor"]},
	"server_corner": {"feet": Vector3(9.8, 0, -14.0), "look": Vector3(12, 1.5, -14.5)},
	"far_wall": {"feet": Vector3(5, 0, -10), "look": Vector3(5, 2.3, -18)},
	# The mail PC (east wall; its mail is on the PC, ADR 0130), and its Mail with the edge router off.
	"mail_pc": {"feet": Vector3(9.2, 0, -8.0), "look": Vector3(12, 1.6, -8.0)},
	"mail_pc_close": {"feet": Vector3(10.4, 0, -9.5), "look": Vector3(12, 1.0, -9.5)},
	"mail_pc_offline":
	{
		"feet": Vector3(10.4, 0, -9.5),
		"look": Vector3(12, 1.45, -9.5),
		"computer": "MailPc",
		"app": "mail",
		"off": ["network_lab_edge"],
	},
	# M12b annex: the doorway both ways, each station, the floor marks.
	"annex_doorway_out": {"feet": Vector3(10, 0, -14.5), "look": Vector3(10, 1.5, -20)},
	"annex_doorway_in": {"feet": Vector3(10.6, 0, -21.5), "look": Vector3(9.8, 1.7, -17)},
	"annex_overview": {"feet": Vector3(9.0, 0, -19.4), "look": Vector3(17, 1.0, -30)},
	"wifi_station": {"feet": Vector3(15.6, 0, -25.5), "look": Vector3(21.6, 2.4, -25.5)},
	"wifi_from_10": {"feet": Vector3(11.6, 0, -25.5), "look": Vector3(21.6, 2.4, -25.5)},
	"wifi_marks": {"feet": Vector3(9.0, 0, -22.5), "look": Vector3(14, 0, -26.5)},
	"wifi_pillar": {"feet": Vector3(16.0, 0, -27.9), "look": Vector3(21.6, 2.4, -25.5)},
	"wifi_sign": {"feet": Vector3(15.5, 0, -21.5), "look": Vector3(15.5, 2.1, -18.5)},
	"wifi_ap": {"feet": Vector3(19.6, 0, -24.2), "look": Vector3(21.7, 2.2, -24.4)},
	"exploit_station": {"feet": Vector3(13.5, 0, -28.8), "look": Vector3(13.5, 1.8, -32.5)},
	"exploit_cameras": {"feet": Vector3(16.8, 0, -29.5), "look": Vector3(16.8, 2.1, -32.5)},
	"firewall_station": {"feet": Vector3(11.5, 0, -25.6), "look": Vector3(7.75, 1.8, -25.6)},
	"firewall_alarm": {"feet": Vector3(10, 0, -22.8), "look": Vector3(7.75, 1.4, -22.8)},
	"firewall_sirens": {"feet": Vector3(10.4, 0, -29.6), "look": Vector3(7.75, 2.3, -29.4)},
	# Screens.
	"pc1_mail":
	{
		"feet": Vector3(-0.9, 0, -8.5),
		"look": Vector3(-2, 1.4, -8.5),
		"computer": "OfficePc1",
		"app": "mail",
		"select": "Re: my password",
	},
	"console_security":
	{
		"feet": Vector3(2.6, 0, -16.9),
		"look": Vector3(2.6, 1.4, -18),
		"computer": "Console",
		"select": "CAM-CLOSET",
	},
	"deck_map_start": {"feet": Vector3(-0.9, 0, -6), "look": Vector3(-2, 0.6, -6), "deck": "Jack"},
	"deck_map_rtr01":
	{"feet": Vector3(-0.9, 0, -6), "look": Vector3(-2, 0.6, -6), "deck": "Jack", "hack": ["BayA/Rtr01"]},
	"deck_map_chained":
	{
		"feet": Vector3(-0.9, 0, -6),
		"look": Vector3(-2, 0.6, -6),
		"deck": "Jack",
		"hack": ["BayA/Rtr01", "BayB/Rtr02"],
	},
	# The deck's AR cable view (RMB) from the hall with the whole M12a chain seen: runs rise from the
	# bays' units to the ceiling.
	"deck_ar_bays":
	{
		"feet": Vector3(4, 0, -10),
		"look": Vector3(-1.5, 1.6, -15.7),
		"deck": "Jack",
		"hack": ["BayA/Rtr01", "BayB/Rtr02"],
		"ar": true,
	},
	"deck_ar_bay_b":
	{
		"feet": Vector3(6, 0, -12),
		"look": Vector3(11.5, 1.8, -15.7),
		"deck": "Jack",
		"hack": ["BayA/Rtr01", "BayB/Rtr02"],
		"ar": true,
	},
	"deck_map_cctv":
	{"feet": Vector3(11.6, 0, -31.6), "look": Vector3(11.6, 0.5, -32.5), "deck": "CctvJack", "menu": "CAM-EX3"},
	"deck_map_alarm":
	{"feet": Vector3(8.65, 0, -22), "look": Vector3(7.75, 0.5, -22), "deck": "AlarmJack", "hack": ["BayC/Rtr04"]},
	"deck_wifi_paused":
	{"feet": Vector3(16.0, 0, -27.9), "look": Vector3(21.6, 2.6, -25.5), "deck": "ApLab", "aim": true, "wait": 2.0},
	"deck_map_wifi":
	# M14b: a jamming field over the Wi-Fi corner: the wireless camera's frame, and the Map from the
	{"feet": Vector3(15.6, 0, -25.5), "look": Vector3(21.6, 2.6, -25.5), "deck": "ApLab", "wifi": true},
	# CCTV jack through RTR-03 (the field starts once the deck has seen the Wi-Fi subnet).
	"jam_frame": {"feet": Vector3(20, 0, -19.7), "look": Vector3(20, 2.6, -18.51), "jam": Vector3(20, 0.1, -21)},
	"jam_map":
	{
		"feet": Vector3(11.6, 0, -31.6),
		"look": Vector3(11.6, 0.5, -32.5),
		"deck": "CctvJack",
		"hack": ["BayC/Rtr03"],
		"jam": Vector3(20, 0.1, -21),
	},
	"switch_off_console":
	{
		"feet": Vector3(2.6, 0, -16.9),
		"look": Vector3(2.6, 1.4, -18),
		"computer": "Console",
		"select": "CAM-CLOSET",
		"off": ["network_lab_closet"],
	},
}

var _queue: Array[String] = []
var _shot: Dictionary = {}
var _out: String = "res://reports/screenshots/network_lab"
var _time: float = 0.0

@onready var _hub: Node3D = $Hub
@onready var _lab: Node3D = $Hub/NetworkLab
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var names := String(args.get("shots", "entrance"))
	var wanted: Array = SHOTS.keys() if names == "all" else Array(names.split(","))
	for shot_name: String in wanted:
		if not SHOTS.has(shot_name):
			push_error("Unknown shot %s; known: %s" % [shot_name, ", ".join(SHOTS.keys())])
			continue
		_queue.append(shot_name)
	_out = String(args.get("out", _out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().size = SHOT_SIZE
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(get_tree().quit)
	_next()


func _next() -> void:
	if _queue.is_empty():
		get_tree().quit()
		return
	var shot_name: String = _queue.pop_front()
	_shot = (SHOTS[shot_name] as Dictionary).duplicate()
	_shot["name"] = shot_name
	_time = 0.0
	for door_name: String in _shot.get("open", []):
		Door.of(_lab.get_node("Doors/" + door_name)).open()
	for circuit: String in _shot.get("off", []):
		Powered.set_circuit(get_tree(), StringName(circuit), false)
	for bay: String in _shot.get("bays", []):
		HingedDoor.of(_lab.get_node("Devices/%s/GlassDoor" % bay)).set_open(true)


func _physics_process(_delta: float) -> void:
	if _shot.is_empty():
		return
	ActorState.set_tag(_player, &"actor.player", false)
	_place_player()
	if _time > 0.3 and not _shot.has("started"):
		_shot["started"] = true
		if _shot.has("computer"):
			_open_computer()
		if _shot.has("deck"):
			_plug_deck()


func _process(delta: float) -> void:
	if _shot.is_empty():
		return
	_time += delta
	var wait := float(_shot.get("wait", 3.0 if _shot.has("deck") else WAIT))
	# A jamming field (M14b) at `jam`: at once, or a second before a deck shot (the Map has seen it all).
	var jam_at := wait - 1.0 if _shot.has("deck") else 0.0
	if _shot.has("jam") and _time > jam_at and not _shot.has("jammed"):
		_shot["jammed"] = true
		ExplosivePayload.spawn_in_level(JAMMING_FIELD, _lab, _lab.to_global(_shot["jam"] as Vector3))
		DeckSession.of(_player).refresh()
	# The Map keeps its view while devices appear: fit it (and open a menu) a moment before the shot.
	if _shot.has("deck") and not _shot.has("aim") and _time > wait - 0.5 and not _shot.has("fitted"):
		_shot["fitted"] = true
		var screen := DeckScreen.of(_player)
		screen.refresh()
		screen.graph.fit_view()
		if _shot.has("menu"):
			screen.graph.select(String(_shot["menu"]))
	# The AR cable view: the Map closed, then RMB's view turned on.
	if _shot.get("ar", false) and _time > wait - 0.4 and not _shot.has("ar_on"):
		_shot["ar_on"] = true
		DeckScreen.of(_player).close()
	if _shot.has("ar_on") and _time > wait - 0.25:
		DeckArView.of(_player).set_active(true)
	if _time < wait:
		return
	var path := "%s/%s.png" % [_out, _shot["name"]]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("Saved ", path)
	var computer_screen := ComputerScreen.of(_player)
	if computer_screen != null and computer_screen.is_open():
		computer_screen.close()
	_shot = {}
	_next()


func _place_player() -> void:
	var space: Node3D = _hub if String(_shot.get("space", "")) == "hub" else _lab
	var feet := space.to_global(_shot["feet"] as Vector3)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := space.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


# Opens the shot's computer on its desktop as its first account, on its app, with `select` selected.
func _open_computer() -> void:
	var entity := _lab.get_node("Devices/" + String(_shot["computer"]))
	var computer := Computer.of(entity)
	computer.open_desktop(_player, DeviceAccounts.of(entity).accounts[0].user, false)
	var screen := ComputerScreen.of(_player)
	var app := String(_shot.get("app", "security"))
	var apps := {"mail": Computer.MAIL, "files": Computer.FILES}
	screen.show_app(apps.get(app, Computer.SECURITY))
	var select := String(_shot.get("select", ""))
	if select.is_empty():
		return
	match app:
		"mail":
			screen.mail_app.select_title(select)
		"files":
			screen.files_app.select_title(select)
		_:
			screen.security_app.select(select)


# Gives the player a deck, holds it and plugs it into the shot's device; grants the `hack` routers.
func _plug_deck() -> void:
	var session := DeckSession.of(_player)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	for router: String in _shot.get("hack", []):
		var accounts := DeviceAccounts.of(_lab.get_node("Devices/" + router))
		accounts.grant(_player, accounts.accounts[0].user)
	if _player.inventory.inventory.stacks_of(&"deck").is_empty():
		_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	var device := Device.of(_lab.get_node("Devices/" + String(_shot["deck"])))
	if _shot.get("aim", false):
		var wireless := WirelessTool.of(_player)
		wireless.aim(device)
		wireless.start()
		return
	if _shot.get("wifi", false):
		AccessPoint.of(device).grant_key(_player)
	session.plug_and_raise(device)
