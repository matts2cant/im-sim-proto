extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 5 (security wing)
## at eye height 1.65 m. Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the
## hub player at a spot, waits, saves the window image (HUD included) and quits. The player loses its
## `actor.player` tag so the camera, the turret and the guard leave it alone. Positions are
## wing-local (origin on the hub wall, +Z into the wing) unless `space` is "hub". `open`: doors
## (paths under Doors/) opened first. `alarm`: the wing's alarm controller is triggered first.
## `network`: the debug panel's network overlay on (ADR 0083). `crouched`: at the crouched eye height
## (0.9 m). `terminal`: the booth terminal's Network tab, logged in, with that device's menu open.

## feet / look: points; space: "hub" (default the wing); wait: seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"space": "hub", "feet": Vector3(7.5, 0, 9), "look": Vector3(7.5, 1.4, 25)},
	"doorway_out": {"feet": Vector3(0, 0, -1.6), "look": Vector3(0.4, 1.4, 4)},
	"doorway_in": {"feet": Vector3(0.9, 0, 2.2), "look": Vector3(-0.3, 1.9, -1)},
	"overview": {"feet": Vector3(10, 0, 0.6), "look": Vector3(-4, 0.6, 6)},
	"overview_west": {"feet": Vector3(-7, 0, 0.6), "look": Vector3(5, 0.8, 6)},
	"table": {"feet": Vector3(-4, 0, 1.8), "look": Vector3(-4, 0.9, 0)},
	"practice_wall": {"feet": Vector3(-3.5, 0, 3), "look": Vector3(-7.5, 1.4, 3)},
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
	"booth": {"feet": Vector3(0.4, 0, 6.8), "look": Vector3(-0.6, 1.3, 9), "open": ["D3Keycard"]},
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
	"laser_terminal":
	{
		"feet": Vector3(-0.25, 0, 8.1),
		"look": Vector3(-0.25, 1.45, 9),
		"terminal": "LaserPair",
		"wait": 2.5,
	},
}

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _opened: bool = false
var _alarm_sent: bool = false
var _terminal_open: bool = false

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
		DebugPanel.network_overlay.enabled = bool(_shot.get("network", false))
	if _shot.has("terminal") and _time > 0.6 and not _terminal_open:
		_terminal_open = true
		_open_terminal(String(_shot["terminal"]))
	if _shot.get("alarm", false) and _time > 0.5 and not _alarm_sent:
		_alarm_sent = true
		StimulusSystem.emit(Device.command_stimulus(Device.TRIGGER, _wing.get_node("Devices/Controller")))
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


# Logs in at the booth terminal, opens its screen on the Network tab and selects `device`.
func _open_terminal(device: String) -> void:
	var terminal := Terminal.of(_wing.get_node("Devices/Terminal"))
	terminal.log_in(terminal.username, terminal.password)
	terminal.use(_player)
	var screen := TerminalScreen.of(_player)
	screen.show_tab(TerminalScreen.Tab.NETWORK)
	screen.refresh_devices(true)
	screen.graph.select(Terminal.display_name(Device.of(_wing.get_node("Devices/" + device))))
