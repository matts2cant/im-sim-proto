class_name ToolUse
extends Node
## Component of any character (ADR 0078): works a held tool on a target while the user keeps at it
## (the player: holding LMB with a lockpick or the deck, on what it looks at). Each tick step() gets
## the target, the kind of tool in hand and whether the user is holding on; it finds the target's
## first component that takes the tool and calls its tool_hold(); letting go, switching target or
## tool calls tool_release() (a lock loses the progress). Knows nothing about specific locks or
## tools: each tick it worked a target it says so (`worked`), so the tool's own component reacts
## without the target knowing it (the deck plugs into a Device it works: DeckSession).
## The tool interface (a component interface, conventions.md): a direct child of the entity in group
## GROUP with `accepts_tool(tool) -> bool`, `tool_hold(user, delta) -> bool` (true: finished) and
## `tool_release(user)` (a Lock, a Device for the deck, ADR 0113). Ranged (ADR 0117): when nothing
## within reach takes the tool, the entity aimed at further away (`aimed`, up to `aim_reach`: the
## deck aimed at an access point) is worked by its first member with
## `accepts_ranged_tool(tool, user) -> bool` true, through the same tool_hold() and tool_release().

## A tick of work on `target` (the component that took the tool) with `tool`.
signal worked(target: Node, tool: StringName)

const GROUP: StringName = &"tool_target"
const ACCEPTS_METHOD: StringName = &"accepts_tool"
const ACCEPTS_RANGED_METHOD: StringName = &"accepts_ranged_tool"
const HOLD_METHOD: StringName = &"tool_hold"
const RELEASE_METHOD: StringName = &"tool_release"

@export var entity_path: NodePath = ^".."
## How far a ranged tool target may be aimed at (m, from the eye; its component decides the rest).
@export var aim_reach: float = 40.0

var entity: Node

var _target: Node = null


func _ready() -> void:
	entity = Entities.of_component(self, entity_path)


static func of(node: Node) -> ToolUse:
	if node == null:
		return null
	for child in node.get_children():
		if child is ToolUse:
			return child as ToolUse
	return null


## One tick of work: `target` (an entity or null), `tool` (ItemData.tool_kind or &""), `holding`;
## `aimed`: the entity aimed at within `aim_reach`, for ranged tool targets (null: none).
func step(target: Node, tool: StringName, holding: bool, delta: float, aimed: Node = null) -> void:
	var found := find_target(target, tool) if holding else null
	if found == null and holding:
		found = find_ranged_target(aimed, tool, entity)
	if found != _target:
		release()
		_target = found
	if _target == null:
		return
	var worked_on := _target
	if bool(_target.call(HOLD_METHOD, entity, delta)):
		_target = null
	worked.emit(worked_on, tool)


## Stops working the current target, if any.
func release() -> void:
	if _target != null and is_instance_valid(_target):
		_target.call(RELEASE_METHOD, entity)
	_target = null


## The first component of `aimed` (in child order) that accepts `tool` from afar for `user`, or null.
static func find_ranged_target(aimed: Node, tool: StringName, user: Node) -> Node:
	if aimed == null or tool.is_empty():
		return null
	for child in Entities.members(aimed, GROUP, ACCEPTS_RANGED_METHOD):
		if bool(child.call(ACCEPTS_RANGED_METHOD, tool, user)):
			return child
	return null


## The first component of `target` (in child order) that accepts `tool` now, or null.
static func find_target(target: Node, tool: StringName) -> Node:
	if target == null or tool.is_empty():
		return null
	for child in Entities.members(target, GROUP, ACCEPTS_METHOD):
		if bool(child.call(ACCEPTS_METHOD, tool)):
			return child
	return null
