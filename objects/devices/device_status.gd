class_name DeviceStatus
extends RefCounted
## What a device shows on a security screen (ADR 0083), collected without knowing what the device
## is. Each behaviour component on a device's entity may offer:
## - `device_status() -> PackedStringArray`: its state in words, in order ("enabled", "sweeping",
##   "ringing", "open", "locked", ...). Words only, never "broken" or "offline": a screen shows a
##   device it cannot reach as offline whatever the reason (unpowered, broken, a dead switch).
## - `device_view() -> Node3D`: the node it sees from (its -Z is the view direction), or null while
##   it sees nothing (disabled). A device has a view when one of its components has the method.
## Entities' direct children are asked, in tree order.

const ONLINE: String = "online"
const OFFLINE: String = "offline"
const STATUS_METHOD: StringName = &"device_status"
const VIEW_METHOD: StringName = &"device_view"


## The words a screen shows for a device: just "offline" when not `online`, else "online" then
## `parts` (duplicates and empty words dropped, "online" / "offline" never repeated).
static func summarize(online: bool, parts: PackedStringArray) -> PackedStringArray:
	if not online:
		return PackedStringArray([OFFLINE])
	var words := PackedStringArray([ONLINE])
	for part in parts:
		if part.is_empty() or part == OFFLINE or words.has(part):
			continue
		words.append(part)
	return words


## Every component's status words for `entity`, in tree order.
static func parts_of(entity: Node) -> PackedStringArray:
	var parts := PackedStringArray()
	if entity == null or not is_instance_valid(entity):
		return parts
	for child in entity.get_children():
		if child.has_method(STATUS_METHOD):
			parts.append_array(child.call(STATUS_METHOD) as PackedStringArray)
	return parts


## summarize() of `entity`'s components (not asked when offline).
static func of(entity: Node, online: bool) -> PackedStringArray:
	return summarize(online, parts_of(entity) if online else PackedStringArray())


## True when a component of `entity` offers a view.
static func has_view(entity: Node) -> bool:
	return _view_component(entity) != null


## The node `entity` sees from now, or null (no view, or it sees nothing).
static func view_of(entity: Node) -> Node3D:
	var component := _view_component(entity)
	return component.call(VIEW_METHOD) as Node3D if component != null else null


static func _view_component(entity: Node) -> Node:
	if entity == null or not is_instance_valid(entity):
		return null
	for child in entity.get_children():
		if child.has_method(VIEW_METHOD):
			return child
	return null
