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
## routers' first account first, `menu` opens that device's menu (its display name). States last
## for the rest of the run: put such shots last.

const SHOT_SIZE := Vector2i(1152, 648)
const WAIT := 1.2
const WATCHDOG := 60.0
const DECK: ItemData = preload("res://items/deck/deck.tres")

const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"space": "hub", "feet": Vector3(-9, 0, -2), "look": Vector3(-16, 1.6, -2)},
	"doorway_out": {"feet": Vector3(0, 0, 1.6), "look": Vector3(0.3, 1.5, -4)},
	"doorway_in": {"feet": Vector3(0.6, 0, -5.4), "look": Vector3(0, 1.7, -2)},
	"entrance": {"feet": Vector3(0, 0, -4.6), "look": Vector3(5, 1.0, -14)},
	"entrance_left": {"feet": Vector3(0.4, 0, -4.6), "look": Vector3(-1.5, 1.0, -12)},
	"overview": {"feet": Vector3(11, 0, -4.6), "look": Vector3(2, 0.6, -14)},
	"deck_table": {"feet": Vector3(2.6, 0, -5.9), "look": Vector3(2.6, 1.0, -4.3)},
	"jack": {"feet": Vector3(-0.6, 0, -6), "look": Vector3(-2, 0.6, -6)},
	"office_pc1": {"feet": Vector3(-0.4, 0, -8.5), "look": Vector3(-2, 1.3, -8.5)},
	"office_pc2": {"feet": Vector3(-0.4, 0, -12), "look": Vector3(-2, 1.3, -12)},
	"rtr01": {"feet": Vector3(0.0, 0, -15.0), "look": Vector3(-2, 1.7, -15.4)},
	"security_corner": {"feet": Vector3(0.6, 0, -15.6), "look": Vector3(0.2, 1.6, -18)},
	"console": {"feet": Vector3(2.6, 0, -16.2), "look": Vector3(2.6, 1.4, -18)},
	"closet_door": {"feet": Vector3(5.85, 0, -15.6), "look": Vector3(5.85, 1.8, -18.25)},
	"closet_open": {"feet": Vector3(5.85, 0, -16.6), "look": Vector3(6, 0.9, -20.7), "open": ["ClosetDoor"]},
	"closet_inside": {"feet": Vector3(6.4, 0, -20.2), "look": Vector3(5.6, 1.5, -17.5), "open": ["ClosetDoor"]},
	"server_corner": {"feet": Vector3(9.8, 0, -14.0), "look": Vector3(12, 1.5, -14.5)},
	"far_wall": {"feet": Vector3(5, 0, -10), "look": Vector3(5, 2.3, -18)},
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
		"select": "Closet Camera",
	},
	"deck_map_start": {"feet": Vector3(-0.9, 0, -6), "look": Vector3(-2, 0.6, -6), "deck": "Jack"},
	"deck_map_rtr01": {"feet": Vector3(-0.9, 0, -6), "look": Vector3(-2, 0.6, -6), "deck": "Jack", "hack": ["Rtr01"]},
	"deck_map_chained":
	{"feet": Vector3(-0.9, 0, -6), "look": Vector3(-2, 0.6, -6), "deck": "Jack", "hack": ["Rtr01", "Rtr02"]},
	"switch_off_console":
	{
		"feet": Vector3(2.6, 0, -16.9),
		"look": Vector3(2.6, 1.4, -18),
		"computer": "Console",
		"select": "Closet Camera",
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
	# The Map keeps its view while devices appear: fit it (and open a menu) a moment before the shot.
	if _shot.has("deck") and _time > wait - 0.5 and not _shot.has("fitted"):
		_shot["fitted"] = true
		var screen := DeckScreen.of(_player)
		screen.refresh()
		screen.graph.fit_view()
		if _shot.has("menu"):
			screen.graph.select(String(_shot["menu"]))
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
	var apps := {"mail": ComputerScreen.App.MAIL, "files": ComputerScreen.App.FILES}
	screen.show_app(apps.get(app, ComputerScreen.App.SECURITY))
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
	session.plug_and_raise(Device.of(_lab.get_node("Devices/" + String(_shot["deck"]))))
