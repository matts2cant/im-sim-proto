class_name DoorController
extends Node
## Component of a door controller (ADR 0130): the network device of a door. A door is not a device;
## its controller on the wall beside it is: its wall boxes (keypad, card reader, status box or plain
## control box) on both faces are one controller device (one Device, one name, one cable, one
## status, one light: the lock light of every box). The controller is an entity of its own
## (`objects/door/door_controller.tscn`: Tags `object.door_controller`, the shared command receptrons,
## Device, DeviceLamp and this component) under the door's DoorHardware (`<door>/Hardware/Controller`):
## a level places one there to put the door on a network (its Device's address, cables and trust, its
## Powered), and DoorHardware builds a default one for a door whose locks put a box on the wall. The
## hardware builds the boxes as its children (each with a DevicePanel: Device.of(box) is this
## controller's Device, from either box) and places it at the front face's first box. A door without
## a box is mechanical: no controller, no Device.
## - Commands: `command.open` / `command.close` run the door's Door.command(); `command.lock` /
##   `command.unlock` lock and unlock its Lockable (the receptrons block them while the controller is
##   unpowered or broken).
## - Power: the door's lock is fed by its controller. While the controller's Device is down
##   (unpowered or broken) the door's entity carries `state.unpowered`, so the door's power rule
##   applies (ElectronicLock: fail-secure stays locked, fail-safe unlocks) and its lock lights go dark.
## - Security screens (DeviceStatus): the door's words (locked / unlocked, then open / closed).
## - Name: its entity's `display_name`, else the door's (its `display_name`, else its node name).

const NODE_NAME: StringName = &"Controller"

@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
## The door it controls (DoorHardware binds it), or null.
var door: Door


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null:
		push_warning("DoorController %s: its entity has no Device" % get_path())
		return
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_state_changed)
	_sync_power()


## The DoorController of `node` (a controller entity, or one of its wall boxes: a DevicePanel of
## its Device), or null.
static func of(node: Node) -> DoorController:
	if node == null:
		return null
	for child in node.get_children():
		if child is DoorController:
			return child as DoorController
	var panel := DevicePanel.of(node)
	if panel != null and panel.target() != null and panel.target().entity != node:
		return DoorController.of(panel.target().entity)
	return null


## Ties the controller to `p_door` (DoorHardware): it acts on that door and feeds its power.
func bind(p_door: Door) -> void:
	door = p_door
	if entity == null:
		entity = get_node_or_null(entity_path) as Node3D
	if entity != null and not entity.has_meta(EntityNames.META) and is_instance_valid(door.entity):
		var door_name: String = String(door.entity.name).capitalize()
		if door.entity.has_meta(EntityNames.META):
			door_name = str(door.entity.get_meta(EntityNames.META))
		entity.set_meta(EntityNames.META, door_name)
	_sync_power()


## True while the controller is up (powered and unbroken): the door's lock has power.
func is_up() -> bool:
	return device != null and device.is_up()


## Status words for security screens (DeviceStatus): the door's lock, then the door.
func device_status() -> Array[StatusWord]:
	var words: Array[StatusWord] = []
	if door == null or not is_instance_valid(door):
		return words
	if door.lockable != null:
		words.append_array(door.lockable.device_status())
	words.append_array(door.device_status())
	return words


## The commands that change something now (DeviceStatus): the door's lock's, then the door's.
func device_commands() -> Array[StringName]:
	var commands: Array[StringName] = []
	if door == null or not is_instance_valid(door):
		return commands
	if door.lockable != null:
		commands.append_array(door.lockable.device_commands())
	commands.append_array(door.device_commands())
	return commands


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	if door == null or not is_instance_valid(door):
		return
	var by: Node = stimulus.source if is_instance_valid(stimulus.source) else null
	match action:
		Door.OPEN, Door.CLOSE:
			door.command(action, by)
		Lockable.LOCK:
			if door.lockable != null:
				door.lockable.lock(by, &"command")
		Lockable.UNLOCK:
			if door.lockable != null:
				door.lockable.unlock(by, &"command")


func _on_state_changed(_up: bool) -> void:
	_sync_power()


# The door's entity carries `state.unpowered` while the controller is down.
func _sync_power() -> void:
	if device == null or door == null or not is_instance_valid(door) or not is_instance_valid(door.entity):
		return
	ActorState.set_tag(door.entity, Device.UNPOWERED, not device.is_up())
