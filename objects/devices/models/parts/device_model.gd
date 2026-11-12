@tool
class_name DeviceModel
extends Node3D
## The root of a device's 3D model (ADR 0130 step 0): the look only, no behaviour. Its parts
## (KindStrip, KindIcon, StatusLed, PortRow, NamePlate) read the device kind from the nearest
## DeviceModel above them, so one model scene names its kind once, by the kind's entity tag in
## DeviceKinds. A rack unit says how many rack units (U) it fills; a LinkingBay snaps it to a slot.
## Conventions: the front faces +Z; a wall model's origin is the centre of its back, a desk model's
## the centre of its footprint on the desk, a rack unit's the bottom centre of its front panel on the
## rack's mounting rails (the body goes back along -Z), a ceiling model's the top centre.

## The entity tag of the device's kind in DeviceKinds (`object.network_switch`).
@export var kind_tag: StringName = &""
## Rack units (1 U = LinkingBay.UNIT) the model fills; 0: not a rack unit.
@export_range(0, 8) var rack_units: int = 0


## The DeviceModel `node` belongs to (itself or the nearest one above it), or null.
static func of(node: Node) -> DeviceModel:
	var current := node
	while current != null:
		if current is DeviceModel:
			return current as DeviceModel
		current = current.get_parent()
	return null


## The kind of the model `node` belongs to, or null.
static func kind_of(node: Node) -> SecurityKind:
	var model := of(node)
	return model.kind() if model != null else null


## This model's kind (DeviceKinds), or null.
func kind() -> SecurityKind:
	return DeviceKinds.shipped().kind_with_tag(kind_tag)
