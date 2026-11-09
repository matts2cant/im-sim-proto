class_name MechanicalLock
extends Lock
## Lock component: a pin-tumbler lock (ADR 0078), a keyhole on the door leaf's handle on both faces
## (ADR 0098: it is picked by looking at the leaf). Its pins are data (`MechanicalLockData`, for
## M10's minigame). The pick hook is the Lock tool interface: a user holding a tool of kind
## `data.tool` (a lockpick) works it through ToolUse. The M8 placeholder: hold LMB for
## pins x `seconds_per_pin` x the picker's `lockpick_time_mult`; letting go (or looking away) loses
## the progress; success unlocks it (and the user wants it open), makes the opening noise (4) and
## consumes nothing. M10 replaces tool_hold() with the minigame without touching doors.
## EventLog `lock.pick_started {entity, time}`, `lock.pick_cancelled`, `lock.picked`.

const TIME_ATTRIBUTE: StringName = &"lockpick_time_mult"
const OPEN_TONE_HZ := 660.0
const HARDWARE: PackedScene = preload("res://objects/locks/hardware/keyhole.tscn")

@export var data: MechanicalLockData

var _progress: PickProgress = null
var _picker: Node = null


func mount() -> int:
	return Mount.LEAF


func hardware() -> PackedScene:
	return HARDWARE


func pin_count() -> int:
	return data.pin_count() if data != null else 0


## Seconds `user` needs to pick it (its `lockpick_time_mult` applied).
func pick_time(user: Node) -> float:
	var per_pin := data.seconds_per_pin if data != null else 1.0
	return LockRules.pick_time(pin_count(), per_pin, Attributes.read(user, TIME_ATTRIBUTE, 1.0))


func locked_reason(_user: Node) -> String:
	return "lockpick"


func accepts_tool(tool: StringName) -> bool:
	return data != null and tool == data.tool and is_locked()


func tool_hold(user: Node, delta: float) -> bool:
	if not is_locked():
		_clear()
		return false
	if _progress == null or _picker != user:
		_picker = user
		_progress = PickProgress.new(pick_time(user))
		_log(&"lock.pick_started", {"time": _progress.required})
	if not _progress.advance(delta):
		return false
	_log(&"lock.picked", {"time": _progress.required})
	_clear()
	make_noise(data.open_noise, OPEN_TONE_HZ)
	return unlock_for(user, &"pick")


func tool_release(_user: Node) -> void:
	if _progress == null:
		return
	_log(&"lock.pick_cancelled", {"fraction": _progress.fraction()})
	_clear()


func tool_progress() -> float:
	return _progress.fraction() if _progress != null else -1.0


func _clear() -> void:
	_progress = null
	_picker = null


func _log(kind: StringName, extra: Dictionary) -> void:
	var target := String(entity.name) if entity != null else ""
	var data_out := {"entity": target}
	data_out.merge(extra)
	EventLog.record(kind, String(_picker.name) if is_instance_valid(_picker) else "", target, data_out)
