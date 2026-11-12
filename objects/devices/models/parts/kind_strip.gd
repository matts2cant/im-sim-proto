@tool
class_name KindStrip
extends ModelPart
## A device model's strip in its kind's colour (ADR 0130): a rack unit's left ear, a standalone
## device's band along its top edge. A box of `size` centred on the node, in the material built from
## the kind's colour (DeviceKinds), so every model of a kind shows the same colour.

@export var size: Vector3 = Vector3(0.2, 0.005, 0.002):
	set(value):
		size = value
		rebuild()


## The strip's colour (its kind's).
func color() -> Color:
	return _kind_color()


func _build() -> void:
	_mesh("Strip", ModelStyle.box(size, ModelStyle.kind_material(_kind_color())), Vector3.ZERO)
