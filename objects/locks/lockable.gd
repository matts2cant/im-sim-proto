class_name Lockable
extends Node
## Component: something that can be locked (ADR 0078): a door today, a drawer or a locker later.
## The Lock components on the same entity (keypad, mechanical, keycard, electronic) are the ways to
## unlock it; a remote command (or anything else) can lock and unlock it too. An entity with a
## Lockable and no Lock is locked until something unlocks it. A user who unlocks it on purpose
## (right code, key, pick) also wants it opened: `unlocked_by_user` (a Door opens). On a network
## device (a `Device` on the entity) the `command.lock` / `command.unlock` actions lock and unlock it
## (the shared device receptrons block them while unpowered or broken).
## A lock may also grant a user one opening without unlocking it (a keycard, ADR 0098: grant()); the
## entity stays locked, so a door is locked again once closed.
## Security screens (ADR 0083): device_status() says locked / unlocked (DeviceStatus).
## EventLog `lock.unlocked` / `lock.locked` / `lock.granted {entity, how}`. Saveable (`locked`).

signal lock_changed(locked: bool)
## A user unlocked it by a lock meant for them, to get through (a Door opens on it).
signal unlocked_by_user(user: Node)
## A lock let a user open it while it stays locked (a keycard swipe: a Door opens on it).
signal access_granted(user: Node)

## Remote commands (on a network device, or its door's controller: DoorController).
const LOCK: StringName = &"command.lock"
const UNLOCK: StringName = &"command.unlock"
const LOCKED: StatusWord = preload("res://objects/devices/status_words/locked.tres")
const UNLOCKED: StatusWord = preload("res://objects/devices/status_words/unlocked.tres")

@export var locked: bool = false
@export var entity_path: NodePath = ^".."

var entity: Node


func _init() -> void:
	add_to_group(DeviceStatus.GROUP)


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	entity = Entities.of_component(self, entity_path)
	var device := Device.of(entity)
	if device != null:
		device.action_received.connect(_on_action)


static func of(node: Node) -> Lockable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Lockable:
			return child as Lockable
	return null


## Status words for security screens (DeviceStatus): locked / unlocked.
func device_status() -> Array[StatusWord]:
	return [LOCKED if locked else UNLOCKED] as Array[StatusWord]


## The command that changes something now (DeviceStatus): Unlock while locked, else Lock.
func device_commands() -> Array[StringName]:
	return [UNLOCK if locked else LOCK] as Array[StringName]


## Unlocks; `how` is logged (`keypad`, `keycard`, `pick`, `power`, `command`). `user_wants_open`: the
## user who unlocked it wants to get through (`unlocked_by_user`). False when it was not locked.
func unlock(by: Node = null, how: StringName = &"", user_wants_open: bool = false) -> bool:
	if not locked:
		return false
	locked = false
	_log(EventKinds.LOCK_UNLOCKED, by, how)
	lock_changed.emit(false)
	if user_wants_open:
		unlocked_by_user.emit(by)
	return true


## A lock lets `by` open it once without unlocking it (`how`: `keycard`); false when it is not
## locked (nothing to grant: the user opens it like any unlocked one).
func grant(by: Node = null, how: StringName = &"") -> bool:
	if not locked:
		return false
	_log(EventKinds.LOCK_GRANTED, by, how)
	access_granted.emit(by)
	return true


## Locks; false when it already was.
func lock(by: Node = null, how: StringName = &"") -> bool:
	if locked:
		return false
	locked = true
	_log(EventKinds.LOCK_LOCKED, by, how)
	lock_changed.emit(true)
	return true


## The Lock components on the entity.
func locks() -> Array[Lock]:
	return Lock.locks_of(entity)


## True when `actor` may pass: unlocked, or a lock lets it through (a keycard it holds, or it
## stands on the lock's free side).
func grants_passage(actor: Node) -> bool:
	if not locked:
		return true
	for each in locks():
		if each.grants_passage(actor) or each.opens_freely_for(actor):
			return true
	return false


## What opens it for `user`: each lock's locked_reason() in lock order ("keycard", "key or
## lockpick"), empty ones skipped (LockRules turns them into the frame's line and E's message).
func reasons(user: Node = null) -> Array[String]:
	var found: Array[String] = []
	for each in locks():
		var reason := each.locked_reason(user)
		if not reason.is_empty():
			found.append(reason)
	return found


## Navigation layers that may plan through it while locked (access ids its locks let through).
func passage_layers() -> int:
	var layers := 0
	for each in locks():
		layers |= each.passage_layers()
	return layers


func save_state() -> Dictionary:
	return {"locked": locked}


func load_state(data: Dictionary) -> void:
	var value := bool(data.get("locked", locked))
	if value != locked:
		locked = value
		lock_changed.emit(locked)


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	var by: Node = stimulus.source if is_instance_valid(stimulus.source) else null
	if action == Lockable.LOCK:
		lock(by, &"command")
	elif action == Lockable.UNLOCK:
		unlock(by, &"command")


func _log(kind: StringName, by: Node, how: StringName) -> void:
	var who := String(by.name) if is_instance_valid(by) else ""
	var target := String(entity.name) if is_instance_valid(entity) else ""
	EventLog.record(kind, who, target, {"entity": target, "how": how})
