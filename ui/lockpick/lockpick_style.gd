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
## The caption panel's style (LockpickCaption).
const THEME: Theme = preload("res://ui/lockpick/lockpick_theme.tres")

var _mono: SystemFont = null
var _textures: Dictionary[String, GradientTexture2D] = {}


func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(
			["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"]
		)
	return _mono


## A box drawn by the side view's _draw() (draw_style_box), in its drawing colours.
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


## A vertical linear gradient texture (top to bottom) through `colours` at `offsets`, cached by `key`.
func linear(key: String, colours: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	if _textures.has(key):
		return _textures[key]
	var gradient := Gradient.new()
	gradient.colors = colours
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128
	_textures[key] = texture
	return texture


## Draws `points` on `canvas` filled with the vertical gradient `texture` running from `y0` to `y1`
## (clamped past them), tinted by `modulate`.
static func fill_vertical(
	canvas: CanvasItem, points: PackedVector2Array, texture: Texture2D, y0: float, y1: float, modulate: Color
) -> void:
	var uvs := PackedVector2Array()
	var span := maxf(y1 - y0, 0.001)
	for point in points:
		uvs.append(Vector2(0.5, clampf((point.y - y0) / span, 0.0, 1.0)))
	canvas.draw_colored_polygon(points, modulate, uvs, texture)


## Points of `rect` with corners rounded by `radius` (clockwise from the top-left corner's end).
static func rounded_rect(rect: Rect2, radius: float, segments: int = 6) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var points := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	for c in 4:
		var start := -PI / 2.0 + c * PI / 2.0
		for k in segments + 1:
			points.append(corners[c] + Vector2.from_angle(start + PI / 2.0 * k / segments) * r)
	return points


## The corners of `rect` as a polygon.
static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	)


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
