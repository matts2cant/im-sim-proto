class_name DeviceSwitch
extends Node
## Component (ADR 0113): lets remote commands switch a device off and on, for any device whose own
## behaviour has no switch of its own (a panic button, a radio base station; laser arrays, cameras
## and turrets keep theirs). `command.disable` / `command.enable` arrive through the entity's
## receptrons (DeviceActionEffect, blocked while unpowered or broken) and its Device's
## `action_received`; the entity's other components ask is_enabled(entity) before acting.
## Security screens (DeviceStatus): "enabled" / "disabled", device_disabled().
## EventLog: `device.toggled {device, enabled}`. Saveable (`disabled`).
## DISABLE / ENABLE are the switch-off commands of every device that can be switched off (cameras,
## laser arrays, turrets and alarm controllers handle them in their own components).

const DISABLE: StringName = &"command.disable"
const ENABLE: StringName = &"command.enable"

## Starts switched off (a `command.enable` turns it on).
@export var start_disabled: bool = false
@export var entity_path: NodePath = ^".."

var entity: Node
var disabled: bool = false


func _ready() -> void:
	add_to_group(&"saveable")
	disabled = start_disabled
	entity = get_node_or_null(entity_path)
	var device := Device.of(entity)
	if device == null:
		push_warning("DeviceSwitch %s: needs a Device on its entity" % get_path())
		return
	device.action_received.connect(_on_action)


## The DeviceSwitch of `node` (an entity), or null.
static func of(node: Node) -> DeviceSwitch:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is DeviceSwitch:
			return child as DeviceSwitch
	return null


## True unless `node`'s DeviceSwitch is off (no switch: always enabled).
static func is_enabled(node: Node) -> bool:
	var switch := DeviceSwitch.of(node)
	return switch == null or not switch.disabled


func set_disabled(off: bool) -> void:
	if disabled == off:
		return
	disabled = off
	var device_name := String(entity.name) if entity != null else String(name)
	EventLog.record(EventKinds.DEVICE_TOGGLED, device_name, "", {"device": device_name, "enabled": not off})


func device_disabled() -> bool:
	return disabled


func device_status() -> Array[StatusWord]:
	return [DeviceStatus.DISABLED if disabled else DeviceStatus.ENABLED] as Array[StatusWord]


## Switched off, only Enable; else Disable (DeviceStatus).
func device_commands() -> Array[StringName]:
	return [ENABLE if disabled else DISABLE] as Array[StringName]


func _on_action(action: StringName, _stimulus: Stimulus) -> void:
	match action:
		DeviceSwitch.DISABLE:
			set_disabled(true)
		DeviceSwitch.ENABLE:
			set_disabled(false)


func save_state() -> Dictionary:
	return {"disabled": disabled}


func load_state(data: Dictionary) -> void:
	disabled = bool(data.get("disabled", disabled))
