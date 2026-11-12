@tool
class_name KindIcon
extends ModelPart
## A device model's kind icon (ADR 0130): the kind's Map icon (SecurityKind.icon, DeviceKinds) as a
## thin line mesh (IconMesh) `side` metres square, centred on the node, printed just proud of the
## surface the node sits on (+Z), in the kind's colour.

## Out of the surface (m).
const PROUD: float = 0.0005

@export var side: float = 0.02:
	set(value):
		side = value
		rebuild()


func _build() -> void:
	var kind := _kind()
	if kind == null:
		return
	var mesh := IconMesh.build(kind.icon, side)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, ModelStyle.kind_material(kind.color))
	var icon := _mesh("Icon", mesh, Vector3(0.0, 0.0, PROUD))
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
