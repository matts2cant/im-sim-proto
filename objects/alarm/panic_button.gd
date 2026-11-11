class_name PanicButton
extends Usable
## Component (ADR 0075, ADR 0077): the old alarm panel. Using it (E: "press panic button") makes the
## entity's Device report an incident at the button (Device.report_incident()) to every alarm
## controller it reaches. Silent: no noise. Unpowered, broken, cut off or switched off by a remote
## `command.disable` (its DeviceSwitch, M12a), it still clicks in but nothing is told.
## EventLog: `device.panic {button, by, controllers}`.

@export var label: String = "panic button"
@export var entity_path: NodePath = ^".."

var entity: Node3D


func _ready() -> void:
	verb = "press"
	entity = get_node_or_null(entity_path) as Node3D


func target_name() -> String:
	return label


func use(user: Node) -> bool:
	var device := Device.of(entity)
	var told := 0
	if device != null and DeviceSwitch.is_enabled(entity):
		told = device.report_incident(entity.global_position)
	var by := String(user.name) if user != null else ""
	var button := String(entity.name) if entity != null else ""
	EventLog.record(&"device.panic", by, button, {"button": button, "by": by, "controllers": told})
	used.emit(user)
	return true
