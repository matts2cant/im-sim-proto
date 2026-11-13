class_name DoorControl
extends Usable
## Component of a door's wall box (ADR 0098): a keypad, a card reader, an electronic lock's status box
## or a plain control box, which DoorHardware builds beside the frame on both faces as the panels of
## the door's controller (ADR 0130; the box's DevicePanel is the controller's Device). E on the box works
## the door through the box's lock: "E: close" while open, "E: open" while unlocked (or from a free
## side), else what its lock offers ("E: enter code", "E: open (keycard)"), else "Locked: <what opens
## it>". A box without a lock (`lock` null: a plain control, a status box) only opens and closes.

## The door the box belongs to.
var door: Door
## The lock whose hardware the box is, or null.
var lock: Lock


## The frame names the box after its controller (the door's name, DoorController).
func target_name() -> String:
	var device := Device.of(get_parent())
	if device != null:
		return NetworkSource.display_name(device)
	return Interactor.display_name_of(door.entity) if door != null else ""


func available(user: Node) -> bool:
	return door != null and door.available(user)


## The box works its door's lock: the frame's lock line and E's refusal read the door's Lockable.
func lock_target() -> Lockable:
	return door.lockable if door != null else null


## E without what opens the door: "Locked: needs a keycard" (its door's Lockable, LockRules).
func refusal(user: Node) -> String:
	var target := lock_target()
	if target == null or not target.locked:
		return ""
	return LockRules.needs_message(target.reasons(user))


func prompt(user: Node) -> String:
	return door.prompt_via(user, _locks()) if door != null else ""


func use(user: Node) -> bool:
	if door == null or not door.use_via(user, _locks()):
		return false
	used.emit(user)
	return true


func _locks() -> Array[Lock]:
	var result: Array[Lock] = []
	if lock != null and is_instance_valid(lock):
		result.append(lock)
	return result
