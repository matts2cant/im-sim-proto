@tool
class_name KindStrip
extends ModelPart
## A device model's strip in its kind's colour (ADR 0130): a rack unit's left ear, a standalone
## device's band along its top edge (or round its body), in the material built from the kind's
## colour (DeviceKinds), so every model of a kind shows the same colour. Its shape:
## - BOX: a box of `size` centred on the node;
## - BAND: a ring round the node's +Z axis, centred on the node: `size.x` across, `size.z` long
##   (the access point's ring round its rim); `size.y` is unused.

enum Shape { BOX, BAND }

@export var size: Vector3 = Vector3(0.2, 0.005, 0.002):
	set(value):
		size = value
		rebuild()
@export var shape: Shape = Shape.BOX:
	set(value):
		shape = value
		rebuild()


## The strip's colour (its kind's).
func color() -> Color:
	return _kind_color()


func _build() -> void:
	var material := ModelStyle.kind_material(_kind_color())
	if shape == Shape.BAND:
		var band := CylinderMesh.new()
		band.top_radius = size.x * 0.5
		band.bottom_radius = size.x * 0.5
		band.height = size.z
		band.radial_segments = 48
		band.rings = 1
		band.material = material
		var instance := _mesh("Strip", band, Vector3.ZERO)
		# A cylinder stands on its Y axis: turn it to go round +Z.
		instance.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		return
	_mesh("Strip", ModelStyle.box(size, material), Vector3.ZERO)
