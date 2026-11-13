extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 5 (security wing)
## at eye height 1.65 m. Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the
## hub player at a spot, waits, saves the window image (HUD included) and quits. The player loses its
## `actor.player` tag so the camera, the turret and the guard leave it alone. Positions are
## wing-local (origin on the hub wall, +Z into the wing) unless `space` is "hub". `open`: doors
## (paths under Doors/) opened first. `alarm`: the wing's alarm controller is triggered first.
## `network`: the debug panel's network overlay on (ADR 0083). `crouched`: at the crouched eye height
## (0.9 m). `computer`: the booth computer's Security app, logged in, with that device (a path under
## the wing) selected; `login`: its login screen after reading the booth login datapad (Fill in).
## `disable`: `command.disable` sent to those devices (under Devices/) first; `break`: those devices
## broken first. `deck`: a deck plugged into that device (a path under the wing) with its Map up,
## after `hack` (router paths under the wing) granted their first account; the Map is fitted
## before the shot.

## feet / look: points; space: "hub" (default the wing); wait: seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"space": "hub", "feet": Vector3(7.5, 0, 9), "look": Vector3(7.5, 1.4, 25)},
	"doorway_out": {"feet": Vector3(0, 0, -1.6), "look": Vector3(0.4, 1.4, 4)},
	"doorway_in": {"feet": Vector3(0.9, 0, 2.2), "look": Vector3(-0.3, 1.9, -1)},
	"overview": {"feet": Vector3(10, 0, 0.6), "look": Vector3(-4, 0.6, 6)},
	"overview_west": {"feet": Vector3(-7, 0, 0.6), "look": Vector3(5, 0.8, 6)},
	"table": {"feet": Vector3(-4, 0, 1.8), "look": Vector3(-4, 0.9, 0)},
	# M10d practice locks: the wall from the hall's centre and closer, then in front of each lock.
	"practice_wall": {"feet": Vector3(1.5, 0, 3), "look": Vector3(-7.5, 1.4, 3)},
	"practice_wall_near": {"feet": Vector3(-4.2, 0, 3), "look": Vector3(-7.5, 1.6, 3)},
	"practice_simple": {"feet": Vector3(-6.7, 0, 4.15), "look": Vector3(-7.5, 1.4, 4.15)},
	"practice_standard": {"feet": Vector3(-6.7, 0, 3.4), "look": Vector3(-7.5, 1.4, 3.4)},
	"practice_standard_crouched": {"feet": Vector3(-6.7, 0, 3.4), "look": Vector3(-7.5, 1.3, 3.4), "crouched": true},
	"practice_secure": {"feet": Vector3(-6.7, 0, 2.65), "look": Vector3(-7.5, 1.4, 2.65)},
	"practice_high": {"feet": Vector3(-6.7, 0, 1.9), "look": Vector3(-7.5, 1.4, 1.9)},
	"d1": {"feet": Vector3(-6.4, 0, 3.8), "look": Vector3(-6.4, 1.5, 6.25)},
	"d2": {"feet": Vector3(-3.4, 0, 3.8), "look": Vector3(-3.4, 1.5, 6.25)},
	"d3": {"feet": Vector3(-0.4, 0, 3.8), "look": Vector3(-0.4, 1.5, 6.25)},
	"d4": {"feet": Vector3(2.6, 0, 3.8), "look": Vector3(2.6, 1.5, 6.25)},
	"d5": {"feet": Vector3(5.6, 0, 3.8), "look": Vector3(5.6, 1.5, 6.25)},
	# M9h door hardware (ADR 0098): boxes beside the frames, the pin lock's handle and keyhole on both
	# faces, the handle out of the jamb when open, the vault's status box.
	"hw_d1_keypad": {"feet": Vector3(-6.7, 0, 5.0), "look": Vector3(-7.17, 1.3, 6.0)},
	"hw_d2_hall": {"feet": Vector3(-3.0, 0, 5.0), "look": Vector3(-3.9, 1.0, 6.2)},
	"hw_d2_closet": {"feet": Vector3(-3.0, 0, 7.8), "look": Vector3(-3.9, 1.0, 6.3)},
	"hw_d3_reader": {"feet": Vector3(-0.7, 0, 5.0), "look": Vector3(-1.17, 1.3, 6.0)},
	"hw_d3_open": {"feet": Vector3(-0.6, 0, 5.0), "look": Vector3(0.1, 1.0, 6.25), "open": ["D3Keycard"]},
	"hw_d4": {"feet": Vector3(2.3, 0, 5.0), "look": Vector3(1.83, 1.3, 6.0)},
	"hw_vault": {"feet": Vector3(8.4, 0, 16.6), "look": Vector3(8.23, 1.3, 18.0)},
	"hw_vault_inside": {"feet": Vector3(8.6, 0, 19.8), "look": Vector3(8.23, 1.2, 18.5)},
	"d1_open": {"feet": Vector3(-6.4, 0, 4.6), "look": Vector3(-6.25, 1.0, 8.7), "open": ["D1Keypad"]},
	"closet_inside": {"feet": Vector3(-5.6, 0, 8.5), "look": Vector3(-6.5, 1.4, 6.25), "open": ["D1Keypad"]},
	"booth": {"feet": Vector3(0.4, 0, 6.8), "look": Vector3(-0.6, 1.0, 9), "open": ["D3Keycard"]},
	"network_overlay": {"feet": Vector3(-2, 0, 4.6), "look": Vector3(6, 1.2, 4), "network": true, "wait": 2.5},
	"booth_devices": {"feet": Vector3(-0.4, 0, 6.25), "look": Vector3(1.0, 1.75, 7.85), "open": ["D3Keycard"]},
	"hall_devices": {"feet": Vector3(4.6, 0, 3.4), "look": Vector3(5, 1.7, 0)},
	"corridor_mouth": {"feet": Vector3(9, 0, 3.5), "look": Vector3(9, 1.4, 12)},
	"corridor_back": {"feet": Vector3(9.6, 0, 8.4), "look": Vector3(8.6, 1.6, 4)},
	"corridor_south": {"feet": Vector3(9.8, 0, 11), "look": Vector3(9, 1.6, 18)},
	"alcove_camera": {"feet": Vector3(7.2, 0, 14.4), "look": Vector3(9, 2.5, 18)},
	"alcove_seam": {"feet": Vector3(8.6, 0, 12.6), "look": Vector3(6.5, 1.2, 10.3)},
	"vault_door": {"feet": Vector3(7.9, 0, 15.6), "look": Vector3(9, 1.5, 18.25)},
	"vault_open": {"feet": Vector3(8.2, 0, 16.2), "look": Vector3(9, 1.0, 21), "open": ["VaultDoor"]},
	"vault_inside": {"feet": Vector3(3.8, 0, 19.2), "look": Vector3(9, 0.9, 20.8), "open": ["VaultDoor"]},
	"vault_door_inside": {"feet": Vector3(7.4, 0, 21.4), "look": Vector3(9, 1.4, 18.25), "open": ["VaultDoor"]},
	"alarm": {"feet": Vector3(9.4, 0, 9), "look": Vector3(10.5, 2.8, 12.6), "alarm": true},
	"laser_entry": {"feet": Vector3(-6.25, 0, 7.0), "look": Vector3(-6.1, 0.9, 13), "open": ["D1Keypad"]},
	"laser_low": {"feet": Vector3(-6.0, 0, 9.85), "look": Vector3(-7.0, 0.5, 11.5)},
	"laser_low_crouched": {"feet": Vector3(-6.0, 0, 9.85), "look": Vector3(-7.0, 0.5, 11.5), "crouched": true},
	"laser_high": {"feet": Vector3(-5.2, 0, 13.0), "look": Vector3(-6.6, 1.3, 14.5)},
	"laser_high_crouched": {"feet": Vector3(-5.2, 0, 13.0), "look": Vector3(-6.6, 1.3, 14.5), "crouched": true},
	"laser_pair": {"feet": Vector3(-5.2, 0, 15.2), "look": Vector3(-6.6, 0.9, 16.4)},
	"laser_pair_crouched": {"feet": Vector3(-5.2, 0, 15.2), "look": Vector3(-6.6, 0.9, 16.4), "crouched": true},
	"laser_signs": {"feet": Vector3(-7.0, 0, 13.0), "look": Vector3(-4.5, 1.9, 13.6)},
	"laser_emitters": {"feet": Vector3(-4.9, 0, 12.8), "look": Vector3(-7.5, 0.9, 15.2)},
	"laser_pair_emitter": {"feet": Vector3(-6.0, 0, 15.3), "look": Vector3(-7.45, 0.85, 16.4)},
	"laser_pair_receiver": {"feet": Vector3(-6.0, 0, 15.3), "look": Vector3(-4.55, 0.85, 16.4)},
	"laser_computer":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"computer": "Devices/LaserPair",
		"wait": 2.5,
	},
	# M12a (ADR 0114): the booth computer's login with Fill in, and its Security app on a camera, the
	# vault door and the alarm group (disabled red, broken grey, the rest green).
	"computer_login":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"login": true,
		"wait": 2.0,
	},
	"computer_camera":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"computer": "Devices/Camera",
		"wait": 2.5,
	},
	"computer_door":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"computer": "Doors/VaultDoor",
		"wait": 2.5,
	},
	"computer_states":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"computer": "Devices/Bay/Controller",
		"disable": ["Turret", "LaserHigh"],
		"break": ["SirenCorridor"],
		"wait": 2.5,
	},
	# M12b: the wing's network gear (ADR 0130 step 3: one linking bay with every switch, RTR-05 and the
	# rack alarm controller) and the jack; the deck's Map from the jack before and after RTR-05.
	"network_wall": {"feet": Vector3(5.6, 0, 3.2), "look": Vector3(5.4, 1.6, 0)},
	"bay": {"feet": Vector3(4.6, 0, 2.1), "look": Vector3(4.6, 1.15, 0.3)},
	"bay_units": {"feet": Vector3(4.6, 0, 1.05), "look": Vector3(4.6, 1.4, 0.55)},
	"bay_units_low": {"feet": Vector3(4.6, 0, 1.05), "look": Vector3(4.6, 1.1, 0.55)},
	"jack": {"feet": Vector3(-2.15, 0, 1.8), "look": Vector3(-2.15, 0.8, 0)},
	"booth_desk": {"feet": Vector3(-0.25, 0, 7.0), "look": Vector3(-0.25, 0.95, 8.8), "open": ["D3Keycard"]},
	"booth_desk_close": {"feet": Vector3(-0.1, 0, 7.6), "look": Vector3(-0.25, 0.95, 8.8), "open": ["D3Keycard"]},
	"deck_map_jack":
	{"feet": Vector3(-2.3, 0, 1.0), "look": Vector3(-2.3, 0.5, 0), "deck": "Devices/Jack", "wait": 3.0},
	"deck_map_jack_rtr05":
	{
		"feet": Vector3(-2.3, 0, 1.0),
		"look": Vector3(-2.3, 0.5, 0),
		"deck": "Devices/Jack",
		"hack": ["Devices/Bay/Rtr05"],
		"wait": 3.0,
	},
}
const DECK: ItemData = preload("res://items/deck/deck.tres")

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _opened: bool = false
var _alarm_sent: bool = false
var _computer_open: bool = false
var _deck_plugged: bool = false
var _fitted: bool = false

@onready var _hub: Node3D = $Hub
@onready var _wing: Node3D = $Hub/SecurityWing
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "overview")), {})
	_out = String(args.get("out", "res://reports/screenshots/wing_shot.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A plain window run ignores --resolution on this machine (840 x 648): force the review size.
	get_window().size = SHOT_SIZE


func _physics_process(_delta: float) -> void:
	if _shot.is_empty():
		return
	ActorState.set_tag(_player, &"actor.player", false)
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()


func _process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	if _time > 0.3 and not _opened:
		_opened = true
		for door_name: String in _shot.get("open", []):
			Door.of(_wing.get_node("Doors/" + door_name)).open()
		for device_name: String in _shot.get("disable", []):
			StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _wing.get_node("Devices/" + device_name)))
		for device_name: String in _shot.get("break", []):
			Device.of(_wing.get_node("Devices/" + device_name)).load_state({"broken": true})
		DebugPanel.network_overlay.enabled = bool(_shot.get("network", false))
	if (_shot.has("computer") or _shot.has("login")) and _time > 0.6 and not _computer_open:
		_computer_open = true
		_open_computer(String(_shot.get("computer", "")))
	if _shot.has("deck") and _time > 0.6 and not _deck_plugged:
		_deck_plugged = true
		_plug_deck()
	if _shot.has("deck") and _time > float(_shot.get("wait", 2.0)) - 0.5 and not _fitted:
		_fitted = true
		var deck_screen := DeckScreen.of(_player)
		deck_screen.refresh()
		deck_screen.graph.fit_view()
	if _shot.get("alarm", false) and _time > 0.5 and not _alarm_sent:
		_alarm_sent = true
		StimulusSystem.emit(Device.command_stimulus(Device.TRIGGER, _wing.get_node("Devices/Bay/Controller")))
	if _time < float(_shot.get("wait", 2.0)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


func _place_player() -> void:
	var space: Node3D = _hub if String(_shot.get("space", "")) == "hub" else _wing
	var feet := space.to_global(_shot["feet"] as Vector3)
	var crouched := bool(_shot.get("crouched", false))
	var eye_height := _player.config.crouched_eye_height if crouched else _player.config.standing_eye_height
	var eye := feet + Vector3.UP * eye_height
	var to := space.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": crouched,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


# Uses the booth computer: on its login after reading the booth login (`device` empty), else logged
# in on the Security app with `device` (a path under the wing) selected.
func _open_computer(device: String) -> void:
	var computer := Computer.of(_wing.get_node("Devices/BoothComputer"))
	Usable.of(_wing.get_node("Items/BoothLogin")).use(_player)
	(_player.get_node("ReadingOverlay") as ReadingOverlay).close()
	var screen := ComputerScreen.of(_player)
	if device.is_empty():
		computer.use_by(_player)
		screen.fill_in(0)
		return
	computer.open_desktop(_player, "rvoss", false)
	screen.show_app(Computer.SECURITY)
	screen.security_app.select(Computer.display_name(Device.of(_wing.get_node(device))))


# Gives the player a deck (fast scans), grants the shot's routers and plugs it into `deck`.
func _plug_deck() -> void:
	var session := DeckSession.of(_player)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	for router: String in _shot.get("hack", []):
		var accounts := DeviceAccounts.of(_wing.get_node(router))
		accounts.grant(_player, accounts.accounts[0].user)
	if _player.inventory.inventory.stacks_of(&"deck").is_empty():
		_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	session.plug_and_raise(Device.of(_wing.get_node(String(_shot["deck"]))))
