class_name ItemIcon
extends RefCounted
## Graybox item icon drawn on any CanvasItem (inventory grid, belt row, belt HUD): a rect of the
## item's colour with a lighter rim, its short name and the stack count; an item with a line icon
## (ItemData.icon, DeviceIcon strokes) shows it above its short name. No image assets.

const TEXT := Color(0.95, 0.95, 0.92)
const SHADOW := Color(0, 0, 0, 0.7)
const COUNT := Color(1.0, 0.92, 0.55)
## Fitted attachments' tag ("SIL").
const TAG := Color(0.55, 0.85, 1.0)
const TAG_SIZE: int = 10


## Draws `stack` filling `rect` (minus a 2 px inset). `alpha` dims it (drag ghost).
static func draw(canvas: CanvasItem, rect: Rect2, stack: ItemStack, font_size: int = 13, alpha: float = 1.0) -> void:
	var font := ThemeDB.fallback_font
	var inner := rect.grow(-2.0)
	var fill := stack.item.colour.darkened(0.35)
	fill.a = 0.92 * alpha
	var rim := stack.item.colour.lightened(0.15)
	rim.a = alpha
	canvas.draw_rect(inner, fill)
	canvas.draw_rect(inner, rim, false, 1.0)
	var text_colour := Color(TEXT, alpha)
	var name_size := font_size
	# Shrink the short name until it fits the icon width.
	while (
		name_size > 8
		and font.get_string_size(stack.item.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > inner.size.x - 6
	):
		name_size -= 1
	var baseline := inner.get_center().y + (font.get_ascent(name_size) - font.get_descent(name_size)) * 0.5
	if not stack.item.icon.is_empty():
		var side := minf(inner.size.x, inner.size.y) * 0.5
		var icon_rect := Rect2(inner.get_center() - Vector2(side * 0.5, side * 0.72), Vector2(side, side))
		DeviceIcon.draw_strokes(canvas, stack.item.icon, icon_rect, text_colour)
		baseline = icon_rect.end.y + font.get_ascent(name_size) + 1.0
	_text(
		canvas,
		font,
		Vector2(inner.position.x, baseline),
		stack.item.short_name,
		inner.size.x,
		name_size,
		text_colour,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var tags := tag_text(stack)
	if not tags.is_empty():
		var top := inner.position.y + 3.0 + font.get_ascent(TAG_SIZE)
		_text(
			canvas,
			font,
			Vector2(inner.position.x, top),
			tags,
			inner.size.x - 5.0,
			TAG_SIZE,
			Color(TAG, alpha),
			HORIZONTAL_ALIGNMENT_RIGHT
		)
	var count := count_text(stack)
	if not count.is_empty():
		var bottom := inner.end.y - 4.0 - font.get_descent(font_size)
		_text(
			canvas,
			font,
			Vector2(inner.position.x, bottom),
			count,
			inner.size.x - 5.0,
			font_size,
			Color(COUNT, alpha),
			HORIZONTAL_ALIGNMENT_RIGHT
		)


## Top-right tag: the short labels of what is fitted to a weapon ("SIL"; ADR 0085), else "".
static func tag_text(stack: ItemStack) -> String:
	var labels: Array[String] = []
	for attachment in Attachments.fitted(stack.state):
		if not attachment.short_label.is_empty():
			labels.append(attachment.short_label)
	return " ".join(labels)


## What the corner shows: the count of a stackable item, a weapon's magazine ("10"), else "".
static func count_text(stack: ItemStack) -> String:
	if stack.item.stackable():
		return str(stack.count)
	if stack.state.has("magazine"):
		return "%d rds" % int(stack.state["magazine"])
	return ""


static func _text(
	canvas: CanvasItem,
	font: Font,
	at: Vector2,
	text: String,
	width: float,
	size: int,
	colour: Color,
	align: HorizontalAlignment
) -> void:
	canvas.draw_string(font, at + Vector2(1, 1), text, align, width, size, Color(SHADOW, colour.a * SHADOW.a))
	canvas.draw_string(font, at, text, align, width, size, colour)
