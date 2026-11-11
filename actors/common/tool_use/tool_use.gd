class_name ToolUse
extends Node
## Component of any character (ADR 0078): works a held tool on a target while the user keeps at it
## (the player: holding LMB with a lockpick or the deck, on what it looks at). Each tick step() gets
## the target, the kind of tool in hand and whether the user is holding on; it finds the target's
## first component that takes the tool (the tool interface: `accepts_tool(tool)`,
## `tool_hold(user, delta) -> bool` (true: finished), `tool_release(user)`; a Lock, a Device for the
## deck, ADR 0113) and calls its tool_hold(); letting go, switching target or tool calls
## tool_release() (a lock loses the progress). Knows nothing about specific locks or tools.

## The user finished working `lock` (it unlocked); null for a tool target that is not a Lock.
signal finished(lock: Lock)

const ACCEPTS_METHOD: StringName = &"accepts_tool"

@export var entity_path: NodePath = ^".."

var entity: Node

var _target: Node = null


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
	var found := find_target(target, tool) if holding else null
	if found != _target:
		release()
		_target = found
	if _target == null:
		return
	if bool(_target.call(&"tool_hold", entity, delta)):
		var done := _target
		_target = null
		finished.emit(done as Lock)


## Stops working the current target, if any.
func release() -> void:
	if _target != null and is_instance_valid(_target):
		_target.call(&"tool_release", entity)
	_target = null


## The lock being worked now, or null.
func active_lock() -> Lock:
	return _target as Lock if is_instance_valid(_target) else null


## The first Lock on `target` that accepts `tool` now, or null.
static func find_lock(target: Node, tool: StringName) -> Lock:
	if target == null or tool.is_empty():
		return null
	for lock in Lock.locks_of(target):
		if lock.accepts_tool(tool):
			return lock
	return null


## The first component of `target` (in child order) that accepts `tool` now, or null.
static func find_target(target: Node, tool: StringName) -> Node:
	if target == null or tool.is_empty():
		return null
	for child in target.get_children():
		if child.has_method(ACCEPTS_METHOD) and bool(child.call(ACCEPTS_METHOD, tool)):
			return child
	return null
