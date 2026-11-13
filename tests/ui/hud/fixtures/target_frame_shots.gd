extends Node3D
## Screenshot helper for reviews (not a test, ADR 0129): the HUD's interaction frame seen from the
## player's eye (1.65 m) in a small yard: a lockpick on a table, a computer on a table, a door up
## close (the frame clamped to the screen) and an unconscious guard. Run the scene in a window with
## `-- shot=<name> out=<png path> [size=WxH]`: it looks at the thing, saves the window image after
## SAVE_AT seconds and quits (a real-time watchdog saves and quits after WATCHDOG seconds).
## Shots: pickup, computer, door, guard; with the status line (ADR 0130): device_online,
## device_cut (its only link, the other switch, unpowered), lamp_off, guard_dead, door_locked (a
## mechanical lock with a key), keychain (the Inventory tab with two keys).

const SHOTS: Dictionary[String, Dictionary] = {
	"pickup": {"feet": Vector3(-4.0, 0, -0.9), "look": Vector3(-4.0, 0.78, -2.0)},
	"computer": {"feet": Vector3(4.0, 0, -0.75), "look": Vector3(4.0, 1.18, -1.9)},
	"door": {"feet": Vector3(0.25, 0, -9.35), "look": Vector3(0.25, 1.45, -10.0)},
	"guard": {"feet": Vector3(0.2, 0, -4.8), "look": Vector3(-0.2, 0.3, -6.0)},
	# The rack switch's 1U body (1.5 to 1.54 m): the look ray meets its front face.
	"device_online": {"feet": Vector3(7.6, 0, -1.8), "look": Vector3(7.6, 1.522, -2.9)},
	"device_cut": {"feet": Vector3(7.6, 0, -1.8), "look": Vector3(7.6, 1.522, -2.9)},
	"lamp_off": {"feet": Vector3(-8.0, 0, -1.6), "look": Vector3(-8.0, 1.8, -2.8)},
	"guard_dead": {"feet": Vector3(0.2, 0, -4.8), "look": Vector3(-0.2, 0.3, -6.0)},
	"door_locked": {"feet": Vector3(0.25, 0, -8.6), "look": Vector3(0.25, 1.45, -10.0)},
	"keychain": {"feet": Vector3(0, 0, 3.0), "look": Vector3(0, 1.6, 6.0)},
}
const LOCKPICK: ItemData = preload("res://items/lockpick/lockpick.tres")
const KEY: ItemData = preload("res://items/key/key.tres")
## Game seconds before the shot (the pickup lands, the guard lies down).
const SAVE_AT: float = 1.2
const PICKUP_AT: float = 0.2
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
	_shot = SHOTS.get(String(args.get("shot", "pickup")), {})
	_out = String(args.get("out", "res://reports/screenshots/target_frame.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	var size := String(args.get("size", "1152x648")).split("x")
	get_window().size = Vector2i(int(size[0]), int(size[1]))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ActorState.set_tag(_guard, ActorState.UNCONSCIOUS, true)
	_set_up(String(args.get("shot", "pickup")))


# What a shot needs besides the view.
func _set_up(shot: String) -> void:
	var switch_a := Device.of($SwitchA)
	switch_a.links.append(switch_a.get_path_to($SwitchB))
	match shot:
		"device_cut":
			(Powered.of($SwitchB) as Powered).on = false
		"lamp_off":
			(Powered.of($WallLamp) as Powered).on = false
		"guard_dead":
			ActorState.set_tag(_guard, ActorState.DEAD, true)
		"door_locked":
			var lock := MechanicalLock.new()
			lock.name = "MechanicalLock"
			lock.data = MechanicalLockData.new()
			lock.data.key_id = &"store_room"
			$Door.add_child(lock)
			Lockable.of($Door).lock(null, &"shot")
		"keychain":
			var keychain := Keychain.of(_player)
			keychain.add(&"bay_a", "Linking bay A", "Found in the office desk")
			keychain.add(&"office", "Warehouse office", "Taken from a guard")
			_player.inventory.add(LOCKPICK, 3)
			_player.inventory.add(KEY, 1, {"key_id": "gate", "key_name": "Gate padlock"})
			# The tabs open only for a player that takes input.
			_player.input_enabled = true
			TabInterface.of(_player).open.call_deferred(0)


func _physics_process(delta: float) -> void:
	if _shot.is_empty():
		return
	if _time < PICKUP_AT and _time + delta >= PICKUP_AT:
		# Once the table's CSG collision is built (a few frames after load).
		var pickup := (load(LOCKPICK.world_scene) as PackedScene).instantiate() as Node3D
		add_child(pickup)
		pickup.global_position = Vector3(-4.0, 0.8, -2.0)
	_time += delta
	_look()


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	var late := Time.get_ticks_msec() - _started_msec > WATCHDOG * 1000.0
	if not late and _time < SAVE_AT:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out, " ", image.get_size(), " frame ", (_player.get_node("Hud") as Hud).target_frame.frame_rect)
	_shot = {}
	get_tree().quit()


func _look() -> void:
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
