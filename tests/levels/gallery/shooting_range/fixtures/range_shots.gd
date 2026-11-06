extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of the shooting range in the hub.
## Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the hub player at a
## station (eye height 1.65 m), optionally draws the pistol (settled reticle), waits, saves the
## window image and quits. Positions are room-local (origin on the hub wall, -Z into the room).

## feet / look: room-local points; pistol: draw it so the reticle shows; wait: game seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"corridor_entry": {"feet": Vector3(0, 0, 3.0), "look": Vector3(0, 1.6, -6)},
	"corridor_exit": {"feet": Vector3(0.4, 0, -2.4), "look": Vector3(0.5, 1.6, -10)},
	"hall_door_back": {"feet": Vector3(1.5, 0, -6.8), "look": Vector3(-0.5, 2.4, -3.6)},
	"firing_line": {"feet": Vector3(4.25, 0, -7.4), "look": Vector3(4.25, 1.0, -30)},
	"lane_40m": {"feet": Vector3(9.25, 0, -7.45), "look": Vector3(9.25, 1.21, -48), "pistol": true},
	"lane_10m": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "pistol": true},
	"melee_corner": {"feet": Vector3(4.6, 0, -6.6), "look": Vector3(8.6, 1.2, -5.6)},
	"melee_behind": {"feet": Vector3(8.6, 0, -5.6), "look": Vector3(9.9, 1.2, -5.6)},
	"blast_lane": {"feet": Vector3(-1.5, 0, -11.0), "look": Vector3(-1.5, 0.3, -20)},
	"blast_line_6m": {"feet": Vector3(-1.5, 0, -14.0), "look": Vector3(-1.5, 0.2, -20)},
	"blast_gap": {"feet": Vector3(-2.9, 0, -6.0), "look": Vector3(-2.2, 0.8, -13)},
	"far_wall": {"feet": Vector3(3.5, 0, -40.0), "look": Vector3(2.6, 0.8, -51.6)},
	"medkits": {"feet": Vector3(3.0, 0, -6.2), "look": Vector3(3.0, 1.0, -4.3)},
}

const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const AMMO: ItemData = preload("res://items/pistol_ammo/pistol_ammo.tres")

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _started: bool = false

@onready var _room: Node3D = $Hub/ShootingRangeRoom
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "firing_line")), {})
	_out = String(args.get("out", "res://reports/screenshots/range_shot.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A plain window run ignores --resolution on this machine (840 x 648): force the review size.
	get_window().size = SHOT_SIZE


func _physics_process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()
	if not _started and _time > 0.2:
		_started = true
		if _shot.get("pistol", false):
			# M5: the player starts empty; the pistol goes to belt slot 1 (index 0).
			_player.inventory.give(PISTOL, 1)
			_player.inventory.give(AMMO, 30)
			_player.inventory.select_slot(0)
	if _started and _shot.get("pistol", false):
		_player.weapons.settle()


func _process(_delta: float) -> void:
	if _shot.is_empty() or _time < float(_shot.get("wait", 1.0)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
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
