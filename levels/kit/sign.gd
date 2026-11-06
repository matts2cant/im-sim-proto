@tool
class_name Sign
extends Label3D
## A graybox sign: Label3D with the kit's text style (white, black outline, fixed sizes) so
## signs read the same everywhere. MEDIUM is readable from about 6 m. Set `text` and `size`;
## turn on the inherited `billboard` to face the camera, or rotate the node to lay it on a floor.

enum Size { SMALL, MEDIUM, LARGE, XLARGE }

const FONT_SIZES: Array[int] = [48, 64, 96, 128]
const OUTLINE_SIZES: Array[int] = [12, 16, 20, 24]

@export var size := Size.MEDIUM:
	set(value):
		size = value
		_apply_style()


func _init() -> void:
	modulate = Color.WHITE
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	pixel_size = 0.005
	_apply_style()


func _apply_style() -> void:
	var index := clampi(size, 0, FONT_SIZES.size() - 1)
	font_size = FONT_SIZES[index]
	outline_size = OUTLINE_SIZES[index]
