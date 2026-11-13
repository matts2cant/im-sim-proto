extends Node
## Screenshot helper (not a test): the lockpicking screen over the lit security showcase. The shot
## named by the SHOT environment variable is saved (UI included) to SHOT_PATH, then it quits.
## Shots: untrained, trained, advanced, master (a 5-pin lock with a spool and a serrated pin on the
## back wall, two pins set, the pick lifting the binding pin, Lockpicking at that tier: brass, + gauge,
## + captions, clear lock), relock (a Standard practice lock mid re-layout, the pins settling), rake (a
## Master raking a 5-pin standard lock), overset (Advanced: the binding pin lifted through its shear
## line, the overset caption) and room (the trained view with the lock on a stand in the middle of the
## room, 2 m away, so the lit room shows around the panel).
## It always quits: after saving, when the screen closes before the shot, on an unknown shot name,
## and after WATCHDOG real seconds whatever happens (it then saves what is shown).

const SIZE := Vector2i(1152, 648)
## Real seconds before the shot is taken anyway and the run quits.
const WATCHDOG := 25.0
const PRACTICE: PackedScene = preload("res://objects/locks/practice_lock/practice_lock.tscn")
const LOCKPICK: ItemData = preload("res://items/lockpick/lockpick.tres")
## On the showcase's back wall, and 0.9 m in front of it.
const LOCK_AT := Vector3(1.0, 1.3, -7.98)
const FEET := Vector3(1.0, 0, -7.1)
const TIERS: Dictionary[String, int] = {
	"untrained": 0, "trained": 1, "advanced": 2, "master": 3, "room": 1, "rake": 3, "overset": 2, "relock": 0
}
## The room shot: the lock on a stand mid-room, the player 2 m back.
const ROOM_LOCK_AT := Vector3(2.0, 1.1, -2.0)
const ROOM_FEET := Vector3(2.0, 0, 0.0)
const MIXED: Array[StringName] = [&"standard", &"spool", &"standard", &"serrated", &"standard"]
const PLAIN: Array[StringName] = [&"standard", &"standard", &"standard", &"standard", &"standard"]

@export var showcase_path: NodePath = ^"../Showcase"

var _show: Node3D
var _player: Player
var _screen: LockpickScreen
var _lock: MechanicalLock
var _shot: String = ""
var _time: float = 0.0
var _done: bool = false


func _ready() -> void:
	DisplayServer.window_set_size(SIZE)
	_show = get_node(showcase_path) as Node3D
	_player = _show.get_node("Player") as Player
	_player.input_enabled = false
	_shot = OS.get_environment("SHOT")
	if _shot.is_empty():
		_shot = "trained"
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(_finish)
	if not TIERS.has(_shot):
		push_error("lockpick_shots: unknown shot '%s'" % _shot)
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	StimulusSystem.emit(Device.command_stimulus(DeviceSwitch.DISABLE, _show.get_node("Turret")))
	StimulusSystem.emit(Device.command_stimulus(DeviceSwitch.DISABLE, _show.get_node("Camera")))
	var body := _add_lock()
	_lock = body.get_node("MechanicalLock") as MechanicalLock
	var feet := _show.to_global(ROOM_FEET if _shot == "room" else FEET)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := body.global_position - eye
	(
		_player
		. load_state(
			{
				"position": feet,
				"yaw": atan2(-to.x, -to.z) + 0.25,
				"pitch": -0.1,
				"crouched": false,
				"velocity": Vector3.ZERO,
			}
		)
	)
	_player.skills.set_tier(&"lockpicking", TIERS.get(_shot, 0))
	_player.inventory.add(LOCKPICK, 2)
	_player.inventory.hold(_player.inventory.grid.stacks_of(&"lockpick")[0])
	await get_tree().physics_frame
	_screen = LockpickScreen.of(_player)
	_screen.open_for(_lock, _player)


func _add_lock() -> StaticBody3D:
	var body: StaticBody3D
	if _shot == "relock":
		body = PRACTICE.instantiate() as StaticBody3D
	else:
		body = StaticBody3D.new()
		body.name = "Locker"
		var lockable := Lockable.new()
		lockable.locked = true
		body.add_child(lockable)
		var lock := MechanicalLock.new()
		lock.name = "MechanicalLock"
		lock.data = MechanicalLockData.new()
		lock.data.pins = PLAIN if _shot == "rake" else MIXED
		lock.data.pin_seed = 4127
		body.add_child(lock)
	body.position = ROOM_LOCK_AT if _shot == "room" else LOCK_AT
	_show.add_child(body)
	return body


func _physics_process(delta: float) -> void:
	var model := _screen.model if _screen != null else null
	if model == null or _done:
		return
	_time += delta
	match _shot:
		"relock":
			_solve(model, 99)
		"rake":
			# Light tension, the tip wiggled along the keyway at 3 Hz in the bottom band.
			model.tension = 0.3
			model.aim = 0.0
			model.aim_x = 2.0 + 1.6 * sin(TAU * 3.0 * _time)
		"overset":
			# A loose pin (not the binding one) shoved to the top, then the pick held (no prying).
			model.tension = 0.45
			var index := 1 if model.binding_index() == 0 else 0
			if model.any_overset():
				model.aim = model.tip
			elif not _at(model, index):
				_drive(model, index, false)
			else:
				model.aim = 1.0
		_:
			# Two pins set, then the pick on the binding pin, part way up.
			model.tension = 0.42
			if model.set_count() < 2:
				_solve(model, 2)
				return
			var index := model.binding_index()
			_drive(model, index, false)
			if _at(model, index):
				model.aim = model.pins[index].shear * 0.8


func _solve(model: PinTumbler, count: int) -> void:
	if model.opened or model.set_count() >= count:
		return
	model.tension = 0.45
	var index := model.binding_index()
	if model.pins[index].spool == PinTumbler.Spool.FALSE_SET:
		model.tension = maxf(0.2, model.pins[index].false_tension - 0.1)
	_drive(model, index, true)


# Heads for pin `index` (aim down and along the keyway until the tip is under it), then, with `lift`,
# aims just over its shear line.
func _drive(model: PinTumbler, index: int, lift: bool) -> void:
	if not _at(model, index):
		model.aim = 0.0
		model.aim_x = index
	elif lift:
		model.aim = model.pins[index].shear + 0.15


func _at(model: PinTumbler, index: int) -> bool:
	return model.pick == index and absf(model.tip_x - index) < 0.05


func _process(_delta: float) -> void:
	if _done or _screen == null:
		return
	var model := _screen.model
	if model == null:
		# The screen closed before the shot (a picked lock, no picks left): keep what is shown.
		push_warning("lockpick_shots: the screen closed before the '%s' shot" % _shot)
		_finish()
		return
	var capture := false
	match _shot:
		"relock":
			capture = _lock.layout_number() == 2 and model.relayout_t > 0.25
		"rake":
			capture = model.set_count() >= 2 and absf(model.tip_x - 2.0) < 1.0
		"overset":
			capture = model.any_overset() and _screen.caption_left > 1.0
		_:
			capture = _time > 0.5 and model.set_count() >= 2 and model.tip > 0.3
	if capture or _time >= 20.0:
		_finish()


# Saves the viewport to SHOT_PATH (default reports/screenshots/lockpick_<shot>.png) and quits.
func _finish() -> void:
	if _done:
		return
	_done = true
	if _screen != null and _screen.model != null:
		_screen.refresh()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SHOT_PATH")
	if path.is_empty():
		path = "res://reports/screenshots/lockpick_%s.png" % _shot
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("lockpick_shots: could not save %s (%d)" % [path, error])
	get_tree().quit(0 if error == OK else 1)
