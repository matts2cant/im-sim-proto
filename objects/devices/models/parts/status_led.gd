@tool
class_name StatusLed
extends ModelPart
## A device model's one status light (ADR 0130), in the shared status light material (StatusLight's
## shader: per-instance colour and blink). Online green by default; a door controller's lock light
## shows red (locked). In a device scene the StatusLight (or a DeviceLamp) drives it. Its shape:
## - SQUARE: a small square LED `size` metres wide, centred on the node, sitting on the surface (+Z);
## - LAMP: a round lamp `size` metres across, centred on the node (half of it shows when the node
##   sits on a surface; the camera's lamp under its head);
## - RING: a thin ring `size` metres across and `ring_width` thick, round the node's +Z axis and
##   centred on the node, half sunk in the surface (the access point's status ring).

enum Shape { SQUARE, LAMP, RING }

const DEPTH: float = 0.003

@export var size: float = 0.007:
	set(value):
		size = value
		rebuild()
@export var shape: Shape = Shape.SQUARE:
	set(value):
		shape = value
		rebuild()
## RING only: the ring's thickness (m).
@export var ring_width: float = 0.004:
	set(value):
		ring_width = value
		rebuild()
@export var color: Color = ModelStyle.ONLINE:
	set(value):
		color = value
		if is_instance_valid(led):
			led.set_instance_shader_parameter(&"led_color", color)

## The LED mesh (null until built).
var led: MeshInstance3D


func _build() -> void:
	match shape:
		Shape.LAMP:
			var sphere := SphereMesh.new()
			sphere.radius = size * 0.5
			sphere.height = size
			sphere.radial_segments = 16
			sphere.rings = 8
			sphere.material = ModelStyle.STATUS_MATERIAL
			led = _mesh("Led", sphere, Vector3.ZERO)
		Shape.RING:
			var torus := TorusMesh.new()
			torus.outer_radius = size * 0.5
			torus.inner_radius = maxf(size * 0.5 - ring_width, 0.0)
			torus.rings = 48
			torus.ring_segments = 8
			torus.material = ModelStyle.STATUS_MATERIAL
			led = _mesh("Led", torus, Vector3.ZERO)
			# A torus goes round its Y axis: turn it to go round +Z.
			led.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		_:
			var mesh := ModelStyle.box(Vector3(size, size, DEPTH), ModelStyle.STATUS_MATERIAL)
			led = _mesh("Led", mesh, Vector3(0.0, 0.0, DEPTH * 0.5))
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	led.set_instance_shader_parameter(&"led_color", color)
