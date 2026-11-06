extends Node3D
## Screenshot helper for reviews (not a test): views of the movement course's steps strip in the
## hub. Run the scene in a window with `-- shot=<name> out=<png path>`: it holds the hub player at
## a course-local spot (eyes 1.65 m above `feet`; a raised `feet` gives an overview), waits, saves
## the window image and quits. Positions are course-local (-Z away from the hub).

## feet / look: course-local points; wait: game seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"steps_overview": {"feet": Vector3(-5.5, 3.5, -4.6), "look": Vector3(-13.0, 0.0, -10.5)},
	"stair_bottom": {"feet": Vector3(-9.0, 0.0, -6.8), "look": Vector3(-9.0, 1.0, -11.0)},
	"stair_top": {"feet": Vector3(-9.0, 1.02, -11.0), "look": Vector3(-9.0, 0.3, -7.0)},
	"stair_far_side": {"feet": Vector3(-9.0, 0.0, -15.6), "look": Vector3(-9.0, 0.6, -11.0)},
	"step_030": {"feet": Vector3(-14.0, 0.0, -7.6), "look": Vector3(-14.0, 0.0, -10.0)},
	"step_045": {"feet": Vector3(-11.5, 0.0, -7.6), "look": Vector3(-11.5, 0.1, -10.0)},
}

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0

@onready var _course: Node3D = $Hub/MovementCourse
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "stair_bottom")), {})
	_out = String(args.get("out", "res://reports/screenshots/course_shot.png"))
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
	# Re-place every tick so the player never drifts or falls; the first ticks let CSG build.
	var feet := _course.to_global(_shot["feet"] as Vector3)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := _course.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _process(_delta: float) -> void:
	if _shot.is_empty() or _time < float(_shot.get("wait", 1.0)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()
