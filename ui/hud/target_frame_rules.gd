class_name TargetFrameRules
extends RefCounted
## Pure logic of the HUD's interaction frame (ADR 0129): which Interactor kinds are framed, the box
## of the target clipped to the camera's near plane, its screen rectangle (padded, clamped inside the
## screen), the corner brackets and where the name tag goes. Sizes are given in pixels at 1080 p and
## scaled by `unit` (the canvas height / 1080), so the frame looks the same at every resolution.

## Canvas height the pixel sizes below are given at.
const REFERENCE_HEIGHT: float = 1080.0
## Space between the target's outline and the frame.
const PADDING: float = 6.0
## The frame stays this far inside the screen's edges (a door up close).
const SCREEN_MARGIN: float = 16.0
## Bracket arms: this share of the frame's shorter side, clamped between ARM_MIN and ARM_MAX.
const ARM_FRACTION: float = 0.15
const ARM_MIN: float = 8.0
const ARM_MAX: float = 24.0
## Bracket line width (never under one physical pixel).
const LINE_WIDTH: float = 1.0
## Gap between the frame's line and the name tag inside it, and between the frame and a tag outside.
const TAG_INSET: float = 4.0
const TAG_GAP: float = 4.0


## True for the Interactor kinds that frame their target: things the player can pick up, use or
## carry (also "Too heavy"); not while carrying something.
static func frames(kind: Interactor.Kind) -> bool:
	return kind in [Interactor.Kind.PICK_UP, Interactor.Kind.USE, Interactor.Kind.CARRY, Interactor.Kind.TOO_HEAVY]


## Pixels at 1080 p -> canvas units for a canvas `height` units high.
static func unit(height: float) -> float:
	return height / REFERENCE_HEIGHT


## The parts of the box with these 8 corners (camera space: the camera looks down -Z) in front of
## the near plane: the corners in front of it and the points where the box's edges cross it. Empty
## when the whole box is behind the plane. Corners are indexed by their axes' bits (AABB.get_endpoint
## order), so two corners whose indices differ by one bit share an edge.
static func clip_to_front(corners: PackedVector3Array, near: float) -> PackedVector3Array:
	var plane := -near
	var points := PackedVector3Array()
	for corner in corners:
		if corner.z <= plane:
			points.append(corner)
	for i in corners.size():
		for bit: int in [1, 2, 4]:
			var j := i | bit
			if j == i or j >= corners.size():
				continue
			var a := corners[i]
			var b := corners[j]
			if (a.z <= plane) != (b.z <= plane):
				points.append(a.lerp(b, (plane - a.z) / (b.z - a.z)))
	return points


## Smallest rectangle holding every point (an empty Rect2 for no points).
static func rect_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


## The frame around `outline` (screen rectangle of the target): padded, then clamped inside a
## `screen`-sized canvas less its margin. No area (hidden) when it lies wholly off the screen.
static func frame_rect(outline: Rect2, screen: Vector2, ui_scale: float) -> Rect2:
	var padded := outline.grow(PADDING * ui_scale)
	var inside := Rect2(Vector2.ZERO, screen).grow(-SCREEN_MARGIN * ui_scale)
	if not padded.intersects(inside):
		return Rect2()
	return padded.intersection(inside)


## Bracket line width in canvas units: LINE_WIDTH at 1080 p scaled with the canvas, and at least one
## physical pixel (`pixels_per_unit`: the window's pixels per canvas unit, the stretch scale).
static func line_width(ui_scale: float, pixels_per_unit: float) -> float:
	return maxf(LINE_WIDTH * ui_scale, 1.0 / maxf(pixels_per_unit, 0.001))


## Length of a bracket's arms: ARM_FRACTION of the frame's shorter side within [ARM_MIN, ARM_MAX],
## and never more than half that side (the brackets never meet).
static func arm_length(frame: Rect2, ui_scale: float) -> float:
	var shorter := minf(frame.size.x, frame.size.y)
	var arm := clampf(ARM_FRACTION * shorter, ARM_MIN * ui_scale, ARM_MAX * ui_scale)
	return minf(arm, shorter * 0.5)


## The bracket bars: for each corner (top-left, top-right, bottom-left, bottom-right) a horizontal and
## a vertical bar `width` thick and `arm` long, inside the frame.
static func bracket_rects(frame: Rect2, arm: float, width: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var left := frame.position.x
	var top := frame.position.y
	var right := frame.end.x
	var bottom := frame.end.y
	for corner: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
		var x := corner.x if corner.x == left else corner.x - arm
		var y := corner.y if corner.y == top else corner.y - width
		rects.append(Rect2(x, y, arm, width))
		x = corner.x if corner.x == left else corner.x - width
		y = corner.y if corner.y == top else corner.y - arm
		rects.append(Rect2(x, y, width, arm))
	return rects


## Top-left of the name tag (`tag` size): inside the frame's top-left corner when the frame holds it
## with room to spare (twice its height), else just above the frame (below it when there is no
## room above), kept on the screen.
static func tag_position(frame: Rect2, tag: Vector2, screen: Vector2, width: float, ui_scale: float) -> Vector2:
	var inset := width + TAG_INSET * ui_scale
	if frame.size.x >= tag.x + 2.0 * inset and frame.size.y >= tag.y * 2.0 + 2.0 * inset:
		return frame.position + Vector2(inset, inset)
	var margin := SCREEN_MARGIN * ui_scale
	var gap := TAG_GAP * ui_scale
	var y := frame.position.y - tag.y - gap
	if y < margin:
		y = frame.end.y + gap
	var x := clampf(frame.position.x, margin, maxf(screen.x - tag.x - margin, margin))
	return Vector2(x, y)
