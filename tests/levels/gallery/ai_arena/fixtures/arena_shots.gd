extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 6 (AI arena) and
## the perception lab's guard at eye height 1.65 m. Run the scene in a window with
## `-- shot=<name> out=<png path>`: it puts the hub player at a spot, waits, saves the window image
## (HUD included) and quits. The player loses its `actor.player` tag so the guards keep to their
## routine in the shot. Positions are arena-local (origin on the hub wall, +Z into the arena) unless
## `space` names the hub or the lab. `tend`: wait (up to 60 s) until a guard has stood by a downed
## ally for 1.5 s (ADR 0071). `carry`: the player picks up that arena node first.

## feet / look: points; space: "hub" or "lab" coordinates (default the arena); wait: seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"space": "hub", "feet": Vector3(-7.5, 0, 9), "look": Vector3(-7.5, 1.4, 25)},
	"doorway": {"feet": Vector3(0, 0, -1.2), "look": Vector3(-2, 1.4, 10)},
	"doorway_seam": {"feet": Vector3(0.3, 0, 1.2), "look": Vector3(-0.2, 2.0, -2)},
	"overview": {"feet": Vector3(5.5, 0, 0.5), "look": Vector3(-6, 0.3, 16)},
	"overview_back": {"feet": Vector3(-11.5, 0, 19.5), "look": Vector3(1, 0.3, 4)},
	"dark_corner": {"feet": Vector3(-1, 0, 12), "look": Vector3(5, 0.8, 19)},
	"downed": {"feet": Vector3(-3.5, 0, 13.5), "look": Vector3(-7.6, 0.3, 9.9), "wait": 0.6},
	"radio_door": {"feet": Vector3(-9, 0, 17.5), "look": Vector3(-13, 1.3, 18.6)},
	"radio_door_inside": {"feet": Vector3(-16.5, 0, 15.5), "look": Vector3(-12.5, 1.4, 18.6)},
	"radio_room": {"feet": Vector3(-15, 0, 18.5), "look": Vector3(-15, 1.2, 1.6)},
	"lab_guard": {"space": "lab", "feet": Vector3(4, 0, -6), "look": Vector3(2.5, 1.2, -16)},
	"waking": {"feet": Vector3(-4, 0, 8), "look": Vector3(-7.4, 0.6, 9.9), "tend": true},
	"carry": {"feet": Vector3(-6, 0, 9.9), "look": Vector3(-2, 0.0, 10), "carry": "Guards/GuardBatonDowned"},
}

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0

@onready var _hub: Node3D = $Hub
@onready var _arena: Node3D = $Hub/AIArena
@onready var _lab: Node3D = $Hub/PerceptionLab
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "overview")), {})
	_out = String(args.get("out", "res://reports/screenshots/arena_shot.png"))
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
	# (Not while carrying: Player.load_state() lets go of what it holds.)
	if not _player.carry.is_carrying():
		_place_player()


func _process(delta: float) -> void:
	_time += delta
	if _shot.is_empty() or _time < float(_shot.get("wait", 1.5)):
		return
	if _shot.has("carry") and not _player.carry.is_carrying():
		_player.carry.pick_up(_arena.get_node(String(_shot["carry"])) as PhysicsBody3D)
		_time = float(_shot.get("wait", 1.5)) - 0.5
		return
	if _shot.get("tend", false) and not _someone_tending() and _time < 60.0:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


func _someone_tending() -> bool:
	for guard in _arena.get_node("Guards").get_children():
		var awareness := GradedAwareness.of_node(guard)
		if awareness == null:
			continue
		var model := awareness.model
		if model.phase == AwarenessModel.Phase.TEND and model.phase_time > 1.5:
			return true
	return false


func _place_player() -> void:
	var spaces := {"hub": _hub, "lab": _lab}
	var space: Node3D = spaces.get(String(_shot.get("space", "")), _arena)
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
