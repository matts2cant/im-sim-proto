class_name DevicePanel
extends Node
## Component of a body that is a panel of a device whose entity is elsewhere (ADR 0130: a door
## controller's wall boxes, one on each face of the wall, are one controller device). Device.of()
## on the body answers that device, so whatever finds a device from what it looks at or hits (the
## deck, the interaction frame, exploit items) reaches the same device from either panel. The deck
## plugs in through it: the tool interface (ToolUse) is the device's.

## The device the panel belongs to.
var device: Device


func _init() -> void:
	add_to_group(ToolUse.GROUP)


## The DevicePanel child of `node`, or null.
static func of(node: Node) -> DevicePanel:
	if node == null:
		return null
	for child in node.get_children():
		if child is DevicePanel:
			return child as DevicePanel
	return null


## Its device while it is valid, else null.
func target() -> Device:
	return device if is_instance_valid(device) else null


func accepts_tool(tool: StringName) -> bool:
	return target() != null and device.accepts_tool(tool)


func tool_hold(user: Node, delta: float) -> bool:
	return target() != null and device.tool_hold(user, delta)


func tool_release(user: Node) -> void:
	if target() != null:
		device.tool_release(user)
