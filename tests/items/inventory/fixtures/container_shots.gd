extends Node3D
## Screenshot helper for reviews (not a test, ADR 0142): the loot containers and a downed guard seen
## from the player's eye (1.65 m) with the HUD's interaction frame. Run the scene in a window with
## `-- shot=<name> out=<png path> [size=WxH]`: it looks at the thing, saves the window image after
## SAVE_AT game seconds and quits (a real-time watchdog saves and quits after WATCHDOG seconds).
## Shots: crate, locker (unlocked), locker_locked, drawers, guard (unconscious), seam (the locker's
## door and keyhole up close).

const SHOTS: Dictionary[String, Dictionary] = {
	"crate": {"feet": Vector3(-3.0, 0, -1.4), "look": Vector3(-3.0, 0.4, -2.75)},
	"locker": {"feet": Vector3(0.0, 0, -1.6), "look": Vector3(0.0, 1.1, -2.9)},
	"locker_locked": {"feet": Vector3(0.0, 0, -1.6), "look": Vector3(0.0, 1.1, -2.9)},
	"drawers": {"feet": Vector3(3.0, 0, -1.6), "look": Vector3(3.0, 0.5, -2.8)},
	"guard": {"feet": Vector3(6.9, 0, -1.2), "look": Vector3(6.9, 0.25, -2.6)},
	"seam": {"feet": Vector3(0.45, 0, -2.3), "look": Vector3(0.2, 1.16, -2.94)},
}
const SAVE_AT: float = 1.2
const WATCHDOG: float = 25.0

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _started_msec: int = 0

@onready var _player: Player = $Player
@onready var _guard: Node3D = $Guard


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var shot := String(args.get("shot", "crate"))
	_shot = SHOTS.get(shot, {})
	_out = String(args.get("out", "res://reports/screenshots/containers.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [shot, ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	var size := String(args.get("size", "1152x648")).split("x")
	get_window().size = Vector2i(int(size[0]), int(size[1]))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ActorState.set_tag(_guard, ActorState.UNCONSCIOUS, true)
	if shot != "locker_locked" and shot != "seam":
		Lockable.of($Locker).unlock(null, &"shot")


func _physics_process(delta: float) -> void:
	if _shot.is_empty():
		return
	_time += delta
	var feet: Vector3 = _shot["feet"]
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := (_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	var late := Time.get_ticks_msec() - _started_msec > WATCHDOG * 1000.0
	if not late and _time < SAVE_AT:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	var frame := (_player.get_node("Hud") as Hud).target_frame
	print("Saved ", _out, " ", image.get_size(), " frame '", frame.name_text(), "' '", frame.status_text(), "' '")
	print(
		"  lock '", frame.lock_text(), "' kind ", _player.interactor.kind, " prompt '", _player.interactor.prompt, "'"
	)
	_shot = {}
	get_tree().quit()
