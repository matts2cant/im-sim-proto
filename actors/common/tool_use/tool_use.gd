class_name ToolUse
extends Node
## Component of any character (ADR 0078): works a held tool on a target while the user keeps at it
## (the player: holding LMB with a lockpick, on what it looks at). Each tick step() gets the target,
## the kind of tool in hand and whether the user is holding on; it finds the target's Lock that
## accepts the tool and calls its tool_hold(); letting go, switching target or tool calls
## tool_release() (the lock loses the progress). Knows nothing about specific locks or tools.

## The user finished working `lock` (it unlocked).
signal finished(lock: Lock)

@export var entity_path: NodePath = ^".."

var entity: Node

var _lock: Lock = null


func _ready() -> void:
	entity = get_node_or_null(entity_path)


static func of(node: Node) -> ToolUse:
	if node == null:
		return null
	for child in node.get_children():
		if child is ToolUse:
			return child as ToolUse
	return null


## One tick of work: `target` (an entity or null), `tool` (ItemData.tool_kind or &""), `holding`.
func step(target: Node, tool: StringName, holding: bool, delta: float) -> void:
	var lock := find_lock(target, tool) if holding else null
	if lock != _lock:
		release()
		_lock = lock
	if _lock == null:
		return
	if _lock.tool_hold(entity, delta):
		var done := _lock
		_lock = null
		finished.emit(done)


## Stops working the current lock, if any.
func release() -> void:
	if _lock != null and is_instance_valid(_lock):
		_lock.tool_release(entity)
	_lock = null


## The lock being worked now, or null.
func active_lock() -> Lock:
	return _lock if is_instance_valid(_lock) else null


## The first Lock on `target` that accepts `tool` now, or null.
static func find_lock(target: Node, tool: StringName) -> Lock:
	if target == null or tool.is_empty():
		return null
	for lock in Lock.locks_of(target):
		if lock.accepts_tool(tool):
			return lock
	return null
