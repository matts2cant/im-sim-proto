@tool
class_name StatusLed
extends ModelPart
## A device model's one status light (ADR 0130): a small square LED `size` metres wide, centred on
## the node and sitting on the surface (+Z), in the shared status light material (StatusLight's
## shader: per-instance colour and blink). Online green by default; a door controller's lock light
## shows red (locked). Step 2 hands it to the device's StatusLight.

const DEPTH: float = 0.003

@export var size: float = 0.007:
	set(value):
		size = value
		rebuild()
@export var color: Color = ModelStyle.ONLINE:
	set(value):
		color = value
		if is_instance_valid(led):
			led.set_instance_shader_parameter(&"led_color", color)

## The LED mesh (null until built).
var led: MeshInstance3D


func _build() -> void:
	var mesh := ModelStyle.box(Vector3(size, size, DEPTH), ModelStyle.STATUS_MATERIAL)
	led = _mesh("Led", mesh, Vector3(0.0, 0.0, DEPTH * 0.5))
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	led.set_instance_shader_parameter(&"led_color", color)
