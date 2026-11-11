extends Node
## Screenshot helper (not a test): the lockpicking screen over the lit security showcase. The shot
## named by the SHOT environment variable is saved (UI included) to SHOT_PATH, then it quits.
## Shots: untrained, trained, advanced, master (a 5-pin lock with a spool and a serrated pin on the
## back wall, two pins set, the pick lifting the binding pin, Lockpicking at that tier) and relock (a
## Standard practice lock mid re-layout, the pins settling) and room (the master view with the lock
## on a stand in the middle of the room, 2 m away, so the room shows around the panel).

const SIZE := Vector2i(1152, 648)
const PRACTICE: PackedScene = preload("res://objects/locks/practice_lock/practice_lock.tscn")
const LOCKPICK: ItemData = preload("res://items/lockpick/lockpick.tres")
## On the showcase's back wall, and 0.9 m in front of it.
const LOCK_AT := Vector3(1.0, 1.3, -7.98)
const FEET := Vector3(1.0, 0, -7.1)
const TIERS: Dictionary[String, int] = {"untrained": 0, "trained": 1, "advanced": 2, "master": 3, "room": 1}
## The room shot: the lock on a stand mid-room, the player 2 m back.
const ROOM_LOCK_AT := Vector3(2.0, 1.1, -2.0)
const ROOM_FEET := Vector3(2.0, 0, 0.0)

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
	await get_tree().physics_frame
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _show.get_node("Turret")))
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _show.get_node("Camera")))
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
	_player.inventory.give(LOCKPICK, 2)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"lockpick")[0])
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
		lock.data.pins = [&"standard", &"spool", &"standard", &"serrated", &"standard"]
		lock.data.pin_seed = 4127
		body.add_child(lock)
	body.position = ROOM_LOCK_AT if _shot == "room" else LOCK_AT
	_show.add_child(body)
	return body


func _physics_process(_delta: float) -> void:
	var model := _screen.model if _screen != null else null
	if model == null or _done:
		return
	if _shot == "relock":
		_solve(model, 99)
		return
	# Two pins set, then the pick on the binding pin, part way up.
	model.tension = 0.42
	if model.set_count() < 2:
		_solve(model, 2)
		return
	var index := model.binding_index()
	if model.goal() != index:
		model.move_pick(signi(index - model.goal()))
	elif not model.is_changing_pin():
		model.target = model.pins[index].shear * 0.8


func _solve(model: PinTumbler, count: int) -> void:
	if model.opened or model.set_count() >= count:
		return
	model.tension = 0.45
	var index := model.binding_index()
	if model.pins[index].spool == PinTumbler.Spool.FALSE_SET:
		model.tension = maxf(0.2, model.pins[index].false_tension - 0.1)
	if model.goal() != index:
		model.move_pick(signi(index - model.goal()))
	elif not model.is_changing_pin():
		model.target = model.pins[index].shear + 0.15


func _process(delta: float) -> void:
	_time += delta
	if _done or _screen == null or _screen.model == null:
		return
	var model := _screen.model
	var capture := _time > 0.5 and model.set_count() >= 2 and not model.is_changing_pin() and model.tip > 0.3
	if _shot == "relock":
		capture = _lock.layout_number() == 2 and _screen.model.relayout_t > 0.25
	if not capture and _time < 20.0:
		return
	_done = true
	_screen.refresh()
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SHOT_PATH")
	if path.is_empty():
		path = "res://reports/screenshots/lockpick_%s.png" % _shot
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()
