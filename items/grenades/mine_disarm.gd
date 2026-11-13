class_name MineDisarm
extends Usable
## Component (ADR 0131): E on its entity while its ProximityTrigger is armed. A user who is crouched
## (`stance.crouch`), whose body is between `min_distance` and `max_distance` m from the mine (the gap
## to its collision shape, as the trigger measures) and whose `mine_disarm` attribute is at least 1
## (the Demolition skill from Trained) picks it back up: `item` goes into its PlayerInventory and the
## entity is removed (no room: nothing happens, "No room in inventory"). Anyone else makes it beep and
## go off `fail_delay` s later (its Fuse, lit for that time). EventLog `mine.disarmed {object, by}`,
## `mine.disarm_failed {object, by, reason}`.

const SKILL_ATTRIBUTE: StringName = &"mine_disarm"
const BEEP_HZ: float = 1800.0

## What the user gets back (the grenade's inventory item).
@export var item: ItemData
@export var min_distance: float = 1.0
@export var max_distance: float = 2.0
@export var fail_delay: float = 0.5

var _audio: AudioStreamPlayer3D


func _init() -> void:
	verb = "disarm"


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "DisarmBeep"
	_audio.bus = GameSettings.EFFECTS_BUS
	_audio.stream = PlaceholderBeep.tone(BEEP_HZ, 0.12)
	_audio.volume_db = -4.0
	_audio.unit_size = 3.0
	# On the entity (this component is a plain Node: the sound plays where the mine is).
	get_parent().add_child.call_deferred(_audio)


func _notification(what: int) -> void:
	# Freed before the deferred add_child ran: the player never got a parent, free it with us.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_audio) and _audio.get_parent() == null:
		_audio.free()


## Only while its trigger is armed (and not already going off).
func available(_user: Node) -> bool:
	var trigger := ProximityTrigger.of(get_parent())
	var fuse := Fuse.of(get_parent())
	return trigger != null and trigger.is_armed and (fuse == null or not fuse.is_lit)


func use(user: Node) -> bool:
	var entity := get_parent() as Node3D
	var reason := refusal_reason(user)
	if not reason.is_empty():
		_fail(entity, user, reason)
		return true
	var inventory := PlayerInventory.of(user)
	if inventory == null or inventory.give(item, 1) > 0:
		if inventory != null:
			Notices.send(user, PlayerInventory.NO_ROOM)
		return false
	var data := {"object": String(entity.name), "by": String(user.name), "item": String(item.id)}
	EventLog.record(&"mine.disarmed", String(user.name), String(entity.name), data)
	used.emit(user)
	entity.queue_free()
	return true


## Why `user` cannot disarm it now ("" when it can): `standing`, `too_close`, `too_far`, `untrained`.
func refusal_reason(user: Node) -> String:
	if not ActorState.has(user, ActorState.CROUCHING):
		return "standing"
	var trigger := ProximityTrigger.of(get_parent())
	if trigger.characters_within(min_distance).has(user):
		return "too_close"
	if not trigger.characters_within(max_distance).has(user):
		return "too_far"
	if Attributes.read(user, SKILL_ATTRIBUTE, 0.0) < 1.0:
		return "untrained"
	return ""


func _fail(entity: Node3D, user: Node, reason: String) -> void:
	var data := {"object": String(entity.name), "by": String(user.name), "reason": reason}
	EventLog.record(&"mine.disarm_failed", String(user.name), String(entity.name), data)
	if _audio.is_inside_tree():
		_audio.play()
	var fuse := Fuse.of(entity)
	if fuse != null:
		fuse.light(fail_delay)
	else:
		var explosive := Explosive.of(entity)
		if explosive != null:
			explosive.explode()
