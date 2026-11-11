class_name LockpickStyle
extends RefCounted
## Colours, fonts and drawing helpers of the lockpicking screen (the prototype's palette,
## design/prototypes/lockpicking_bench.html). The screen owns one (`LockpickScreen.style`): it caches
## the font and gradient textures, freed with the screen.

const BG := Color("0b0e11")
const LINE := Color("2a3540")
const FG := Color("e4e8ec")
const MUTED := Color("6f7c88")
const BRASS := Color("c9a24a")
const STEEL := Color("aab6c1")
const OK := Color("7fd6a2")
const WARN := Color("e6b45a")
const BAD := Color("e2786b")
const ACRYLIC := Color("9fc3d6")

var _mono: SystemFont = null
var _textures: Dictionary[String, GradientTexture2D] = {}


func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(
			["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"]
		)
	return _mono


static func caption_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(10.0 / 255.0, 12.0 / 255.0, 15.0 / 255.0, 0.78)
	box.border_color = LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


static func rounded_box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## A radial gradient texture (centre to edge) through `colours` at `offsets`, cached by `key`.
func radial(key: String, colours: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	if _textures.has(key):
		return _textures[key]
	var gradient := Gradient.new()
	gradient.colors = colours
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_textures[key] = texture
	return texture


## Points of a circle of `radius` around `center`.
static func circle(center: Vector2, radius: float, segments: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		points.append(center + Vector2.from_angle(TAU * i / segments) * radius)
	return points


## UVs mapping `points` into a radial gradient centred on `focus` with radius `reach`.
static func radial_uvs(points: PackedVector2Array, focus: Vector2, reach: float) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point - focus) / (2.0 * reach) + Vector2(0.5, 0.5))
	return uvs


## Points of the quadratic curve from `a` to `b` with control point `control`.
static func quadratic(a: Vector2, control: Vector2, b: Vector2, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


## Draws `text` on `canvas` with its baseline at `at`; `align` -1 left, 0 centred, 1 right of `at.x`.
func text(canvas: CanvasItem, at: Vector2, value: String, size: int, colour: Color, align: int = 0) -> void:
	var font := mono_font()
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := at.x - (width * 0.5 if align == 0 else (width if align > 0 else 0.0))
	canvas.draw_string(font, Vector2(x, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
