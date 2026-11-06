extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of the physics and fire room in
## the hub. Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the hub player
## at a station (eye height 1.65 m), optionally lights or blasts something, waits, saves the
## window image and quits. Positions are room-local (origin on the hub wall, -Z into the room).

## feet / look: room-local points; ignite / damage: node path under the room; wait: game seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"corridor_entry": {"feet": Vector3(0, 0, 3.0), "look": Vector3(0, 1.6, -6)},
	"corridor_exit": {"feet": Vector3(0.4, 0, -2.2), "look": Vector3(0, 1.8, -8)},
	"hall_door_back": {"feet": Vector3(1.5, 0, -6.5), "look": Vector3(0, 2.4, -3.5)},
	"overview": {"feet": Vector3(0, 0, -4.6), "look": Vector3(0, 0.8, -14)},
	"fire_spread": {"feet": Vector3(-2.8, 0, -10.5), "look": Vector3(-2.8, 0.6, -15.5)},
	"brazier": {"feet": Vector3(3.8, 0, -9.5), "look": Vector3(7.6, 0.4, -6)},
	"barrel_alley": {"feet": Vector3(7.5, 0, -9.2), "look": Vector3(7, 0.6, -16.5)},
	"barricade": {"feet": Vector3(-7.0, 0, -12.5), "look": Vector3(-10.25, 1.2, -17)},
	"barricade_door": {"feet": Vector3(-8.6, 0, -17), "look": Vector3(-12, 1.3, -17)},
	"throwables": {"feet": Vector3(-7.5, 0, -4.4), "look": Vector3(-7.5, 0.6, -8.5)},
	"too_heavy": {"feet": Vector3(3.5, 0, -9.0), "look": Vector3(3.5, 1.0, -4.5)},
	"fire_row_mid":
	{
		"feet": Vector3(-2.8, 0, -10.5),
		"look": Vector3(-2.8, 0.6, -15.5),
		"ignite": "FireSpread/FireCrate1",
		"wait": 13.0,
	},
	"barrel_chain_after":
	{
		"feet": Vector3(7.5, 0, -9.2),
		"look": Vector3(5, 0.4, -15.5),
		"damage": "BarrelAlley/Barrel1",
		"wait": 2.5,
	},
}
## Game time sped up for long waits (physics keeps its 1/60 s step).
const FAST_TIME_SCALE := 4.0

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _started: bool = false

@onready var _room: Node3D = $Hub/PhysicsFireRoom
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "overview")), {})
	_out = String(args.get("out", "res://reports/screenshots/room_shot.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if float(_shot.get("wait", 1.0)) > 3.0:
		Engine.time_scale = FAST_TIME_SCALE


func _physics_process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()
	if not _started and _time > 0.2:
		_started = true
		_poke()


func _process(_delta: float) -> void:
	if _shot.is_empty() or _time < float(_shot.get("wait", 1.0)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	Engine.time_scale = 1.0
	get_tree().quit()


func _place_player() -> void:
	var feet := _room.to_global(_shot["feet"] as Vector3)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := _room.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _poke() -> void:
	if _shot.has("ignite"):
		StimulusSystem.emit(Stimulus.make_contact(&"fire", 100.0, _room.get_node(String(_shot["ignite"]))))
	if _shot.has("damage"):
		StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 60.0, _room.get_node(String(_shot["damage"]))))
