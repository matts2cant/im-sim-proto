extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 2 (perception lab)
## at eye height 1.65 m. Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the
## hub player at a spot, optionally opens the breaker or the debug panel's Overlays tab, waits,
## saves the window image (HUD included) and quits. Positions are room-local (origin on the hub
## wall, -Z into the room) unless `hub` is set.

## feet / look: points; hub: hub coordinates; breaker_open: cut the lab circuit; overlays: open
## the debug panel on its Overlays tab; wait: seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"hub_doorway": {"hub": true, "feet": Vector3(7.5, 0, -9), "look": Vector3(7.5, 1.6, -20)},
	"doorway": {"feet": Vector3(0, 0, 1.2), "look": Vector3(2, 1.4, -10)},
	"doorway_seam": {"feet": Vector3(-0.3, 0, -1.2), "look": Vector3(0.2, 2.0, 2.0)},
	"overview": {"feet": Vector3(9.5, 0, -1), "look": Vector3(0, 0.5, -14)},
	"overview_back": {"feet": Vector3(-4.5, 0, -17), "look": Vector3(4, 0.8, -2)},
	"dark_lane": {"feet": Vector3(-2.5, 0, -8), "look": Vector3(2.5, 1.2, -16)},
	"dim_lane": {"feet": Vector3(2.5, 0, -6), "look": Vector3(2.5, 1.2, -16)},
	"lit_lane": {"feet": Vector3(7.5, 0, -8), "look": Vector3(2.5, 1.2, -16)},
	"lanes_from_post": {"feet": Vector3(2.5, 0, -16), "look": Vector3(2.5, 0.8, -6)},
	"lanes_from_post_off": {"feet": Vector3(2.5, 0, -16), "look": Vector3(2.5, 0.8, -6), "breaker_open": true},
	"breaker": {"feet": Vector3(-4.0, 0, -2.6), "look": Vector3(-5.5, 1.3, -2)},
	"breaker_open": {"feet": Vector3(-4.0, 0, -2.6), "look": Vector3(-5.5, 1.3, -2), "breaker_open": true},
	"apron_off": {"feet": Vector3(0, 0, -1.5), "look": Vector3(4, 1.2, -10), "breaker_open": true},
	"overlays": {"feet": Vector3(2.5, 0, -8), "look": Vector3(2.5, 1.2, -16), "overlays": true},
}

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _acted: bool = false

@onready var _hub: Node3D = $Hub
@onready var _room: Node3D = $Hub/PerceptionLab
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "overview")), {})
	_out = String(args.get("out", "res://reports/screenshots/lab_shot.png"))
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
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()


func _process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	if not _acted and _time > 0.5:
		_acted = true
		_act()
	if _time < float(_shot.get("wait", 1.5)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


func _act() -> void:
	if _shot.get("breaker_open", false):
		(Usable.of(_room.get_node("Breaker")) as CircuitBreaker).set_closed(false)
	if _shot.get("overlays", false):
		DebugPanel.set_open(true)
		var tabs := DebugPanel.get_node("TabContainer") as TabContainer
		for index in tabs.get_tab_count():
			if tabs.get_tab_title(index) == "Overlays":
				tabs.current_tab = index


func _place_player() -> void:
	var space: Node3D = _hub if _shot.get("hub", false) else _room
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
