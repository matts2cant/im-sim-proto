@tool
class_name NetworkPanel
extends Node3D
## Kit part (M12c readability, ADR 0122): the painted wall panel behind a wiring closet's network
## gear, so every closet shares one look: a dark panel with a stripe along its top in its subnet's
## colour (`subnet`'s Map colour, Subnet data) and `title` on the stripe. Visual only (no collision):
## the gear hangs on the wall in front of it. Origin: the centre of the panel's back face, on the wall
## face, +Z out of the wall; the panel stands GAP m off the wall (never coplanar with it).

const GAP: float = 0.002
const DEPTH: float = 0.012
const STRIPE_HEIGHT: float = 0.07
const PANEL_COLOR: Color = Color(0.42, 0.46, 0.5)
## A stripe without subnet data (the Subnet default hue).
const DEFAULT_STRIPE: Color = Color(0.5, 0.66, 0.64)

## Width and height (m).
@export var size: Vector2 = Vector2(1.6, 1.0):
	set(value):
		size = value
		_rebuild()
## The subnet whose colour the stripe takes.
@export var subnet: Subnet:
	set(value):
		subnet = value
		_rebuild()
## Written on the stripe.
@export var title: String = "NETWORK":
	set(value):
		title = value
		_rebuild()


func _ready() -> void:
	_rebuild()


## The stripe's colour: the subnet's Map colour.
func stripe_color() -> Color:
	return subnet.map_color if subnet != null else DEFAULT_STRIPE


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	_box("Panel", Vector3(size.x, size.y, DEPTH), Vector3(0, 0, GAP + DEPTH * 0.5), PANEL_COLOR)
	var stripe_y := size.y * 0.5 - STRIPE_HEIGHT * 0.5 - 0.02
	var front := GAP + DEPTH
	_box("Stripe", Vector3(size.x - 0.04, STRIPE_HEIGHT, 0.004), Vector3(0, stripe_y, front + 0.002), stripe_color())
	var label := Label3D.new()
	label.name = "Title"
	label.set_meta(&"generated", true)
	label.text = title
	label.font_size = 44
	label.pixel_size = 0.001
	label.outline_size = 0
	label.modulate = Color(0.05, 0.05, 0.05)
	label.position = Vector3(0, stripe_y, front + 0.0045)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label, false, Node.INTERNAL_MODE_FRONT)


func _box(node_name: String, box_size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.set_meta(&"generated", true)
	instance.mesh = mesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance, false, Node.INTERNAL_MODE_FRONT)
