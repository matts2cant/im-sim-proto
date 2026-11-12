@tool
class_name ModelText
extends Label3D
## Printed text on a device model (ADR 0130 step 0): name plates, port labels, displays and
## buttons. The models' font (a signed distance field, sharp up close), lit like the surface it is
## printed on (unless `glowing`: a display), sized by its em height in metres.

const FONT_SIZE: int = 32

## The em height of the text in metres (a mono glyph is about 0.6 of it wide).
@export var text_height: float = 0.004:
	set(value):
		text_height = maxf(value, 0.0001)
		pixel_size = text_height / float(FONT_SIZE)
## Lit by itself (a display), not by the room.
@export var glowing: bool = false:
	set(value):
		glowing = value
		shaded = not glowing


func _init() -> void:
	font = ModelStyle.FONT
	font_size = FONT_SIZE
	outline_size = 0
	shaded = true
	double_sided = false
	alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pixel_size = text_height / float(FONT_SIZE)


## The width of `p_text` at `height` (an estimate from the mono advance: no font metrics needed).
static func width_of(p_text: String, height: float) -> float:
	return float(p_text.length()) * height * 0.6
