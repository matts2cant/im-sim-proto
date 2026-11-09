class_name DoorLayout
extends RefCounted
## Pure placement of a door's leaf and hardware (ADR 0098), in door-local metres: origin on the floor
## at the doorway's centre, X along the wall, +Z its front face, the wall's middle plane at z 0.
## - The leaf (panel) fills the settings' doorway plus 5 cm on each side and on top.
## - Its handle sits on the leaf's leading edge (the edge facing away from `travel`) at handle height,
##   proud of both faces. A leaf that slides into the wall (in_wall()) carries the handle past its
##   leading edge too, so the handle still stands out of the jamb when the door is open (it is what
##   E closes the door by). A rising leaf (a roller door) has a bar near its bottom instead.
## - A leaf lock's fitting (a keyhole) goes on the handle's face, on both faces.
## - Wall boxes (keypad, card reader, status, plain control) hang on the wall faces beside the frame
##   on the side away from the pocket (-X for a leaf sliding to +X), stacked downward from BOX_TOP;
##   on a short corridor's side wall (`side_wall` > 0, Door.front_side_wall / back_side_wall) they
##   face across the corridor, SIDE_DEPTH in from the door's wall face.

## Centre height (m above the floor) of a sliding leaf's handle.
const HANDLE_HEIGHT := 1.0
## The handle's height (m), its length on the leaf from the leading edge and past it (leaf in a
## wall only), and how far it stands proud of each leaf face.
const HANDLE_SIZE := 0.36
const HANDLE_ON_LEAF := 0.2
const HANDLE_BEYOND := 0.12
const HANDLE_PROUD := 0.025
## A leaf lock's keyhole: this far in from the leading edge and below the handle's centre.
const KEYHOLE_IN := 0.12
const KEYHOLE_DROP := 0.09
## A rising leaf's handle: a bar this high above the floor (centre), this wide and tall.
const BAR_HEIGHT := 0.3
const BAR_SIZE := Vector2(0.5, 0.08)
## Doorway edge to the wall boxes' centre line (m): every box (at most 0.12 m wide) clears the leaf's
## 5 cm overlap and fits a 0.3 m gate post.
const BOX_COLUMN := 0.17
## Centre height of the top wall box, and the gap between stacked boxes (surface to surface).
const BOX_TOP := 1.35
const BOX_GAP := 0.06
## A box on a corridor's side wall: its centre this far from the door's wall face.
const SIDE_DEPTH := 0.4


## The leaf's outer size: the doorway plus its overlap.
static func panel_size(settings: DoorSettings) -> Vector3:
	return Vector3(settings.doorway.x + 0.1, settings.doorway.y + 0.05, settings.panel_thickness)


## The closed leaf's centre.
static func closed_centre(settings: DoorSettings) -> Vector3:
	return Vector3(0.0, panel_size(settings).y * 0.5 + 0.005, settings.panel_offset)


## True when the leaf moves along the wall (a pocket door, a gate), false when it rises.
static func slides_sideways(settings: DoorSettings) -> bool:
	return absf(settings.travel.x) >= absf(settings.travel.y)


## The side (-1: -X, +1: +X) of the doorway where the wall boxes go: away from the pocket.
static func box_side(settings: DoorSettings) -> float:
	return 1.0 if settings.travel.x < 0.0 else -1.0


## True when the leaf and its handle stay inside a wall `wall_thickness` thick (a pocket door), so
## the open leaf disappears into it; false for a leaf outside the wall line (a gate past its posts).
static func in_wall(settings: DoorSettings, wall_thickness: float) -> bool:
	var reach := absf(settings.panel_offset) + settings.panel_thickness * 0.5 + HANDLE_PROUD
	return reach < wall_thickness * 0.5


## The handle's box, relative to the leaf's centre.
static func handle_box(settings: DoorSettings, wall_thickness: float) -> AABB:
	var half := panel_size(settings) * 0.5
	var depth := settings.panel_thickness + 2.0 * HANDLE_PROUD
	var centre := closed_centre(settings)
	if not slides_sideways(settings):
		var bar_y := BAR_HEIGHT - centre.y
		return AABB(
			Vector3(-BAR_SIZE.x * 0.5, bar_y - BAR_SIZE.y * 0.5, -depth * 0.5), Vector3(BAR_SIZE.x, BAR_SIZE.y, depth)
		)
	var lead := box_side(settings)
	var beyond := HANDLE_BEYOND if in_wall(settings, wall_thickness) else 0.0
	var inner := lead * (half.x - HANDLE_ON_LEAF)
	var outer := lead * (half.x + beyond)
	var y := HANDLE_HEIGHT - centre.y
	var from := Vector3(minf(inner, outer), y - HANDLE_SIZE * 0.5, -depth * 0.5)
	return AABB(from, Vector3(absf(outer - inner), HANDLE_SIZE, depth))


## Where a leaf fitting (keyhole) sits, relative to the leaf's centre: on the handle's face on the
## front (+Z) or back side, its +Z out of that face.
static func keyhole(settings: DoorSettings, front: bool) -> Transform3D:
	var half := panel_size(settings) * 0.5
	var centre := closed_centre(settings)
	var z := settings.panel_thickness * 0.5 + HANDLE_PROUD
	var at := Vector3.ZERO
	if slides_sideways(settings):
		var lead := box_side(settings)
		at = Vector3(lead * (half.x - KEYHOLE_IN), HANDLE_HEIGHT - KEYHOLE_DROP - centre.y, 0.0)
	else:
		at = Vector3(BAR_SIZE.x * 0.5 + 0.08, BAR_HEIGHT - centre.y, 0.0)
	at.z = z if front else -z
	return Transform3D(Basis.IDENTITY if front else Basis(Vector3.UP, PI), at)


## The centre heights of wall boxes `heights` tall, stacked downward from BOX_TOP.
static func box_heights(heights: Array[float]) -> Array[float]:
	var result: Array[float] = []
	var y := BOX_TOP
	for i in heights.size():
		if i > 0:
			y -= heights[i - 1] * 0.5 + BOX_GAP + heights[i] * 0.5
		result.append(y)
	return result


## Where a wall box's origin (its back face's centre, +Z out) goes, `y` m up, on the front (+Z) or
## back face of a wall `wall_thickness` thick; `side_wall` > 0 puts it on that face's corridor side
## wall (that far from the doorway's centre line), facing across the corridor.
static func box_transform(
	settings: DoorSettings, wall_thickness: float, side_wall: float, front: bool, y: float
) -> Transform3D:
	var face := wall_thickness * 0.5 * (1.0 if front else -1.0)
	var side := box_side(settings)
	if side_wall > 0.0:
		var depth := (wall_thickness * 0.5 + SIDE_DEPTH) * (1.0 if front else -1.0)
		return Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * side_wall, y, depth))
	var x := side * (settings.doorway.x * 0.5 + BOX_COLUMN)
	return Transform3D(Basis.IDENTITY if front else Basis(Vector3.UP, PI), Vector3(x, y, face))


## The space the leaf and its handle sweep from closed to open.
static func sweep(settings: DoorSettings, wall_thickness: float) -> AABB:
	var size := panel_size(settings)
	var centre := closed_centre(settings)
	var handle := handle_box(settings, wall_thickness)
	var closed := AABB(centre - size * 0.5, size).merge(AABB(centre + handle.position, handle.size))
	var opened := AABB(closed.position + settings.travel, closed.size)
	return closed.merge(opened)
