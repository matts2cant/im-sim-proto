@tool
class_name NamePlate
extends ModelPart
## A device model's name plate (ADR 0130): a light plate `size` metres (width, height) centred on
## the node, sitting on the surface (+Z), with the name in dark text fitted to the plate.

const DEPTH: float = 0.0012
## Text height as a share of the plate's height, and the share of its width text may fill.
const TEXT_SHARE: float = 0.62
const WIDTH_SHARE: float = 0.9

@export var text: String = "DEVICE":
	set(value):
		text = value
		rebuild()
@export var size: Vector2 = Vector2(0.078, 0.012):
	set(value):
		size = value
		rebuild()

## The text (null until built).
var label: ModelText


## The text height that fits `p_text` on a plate of `p_size`.
static func fitted_height(p_text: String, p_size: Vector2) -> float:
	var height := p_size.y * TEXT_SHARE
	var wide := ModelText.width_of(p_text, height)
	if wide > p_size.x * WIDTH_SHARE and wide > 0.0:
		height *= p_size.x * WIDTH_SHARE / wide
	return height


func _build() -> void:
	var plate := _mesh(
		"Plate", ModelStyle.box(Vector3(size.x, size.y, DEPTH), ModelStyle.PLATE), Vector3(0, 0, DEPTH * 0.5)
	)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, DEPTH + 0.0003))
	label = _text("Name", text, fitted_height(text, size), ModelStyle.PLATE_TEXT, at)
