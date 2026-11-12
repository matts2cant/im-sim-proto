class_name Reticle
extends Control
## HUD crosshair (Deus Ex style; user request 2026-11-12, ADR 0123): a centre dot and, with a ranged
## weapon, four thin arms (up, down, left, right) whose inner ends sit on the aim cone's radius
## (AimModel.reticle_radius), so the crosshair opens and closes with the accuracy; a cone tighter
## than the minimum gap keeps the arms at that gap, so the crosshair never collapses to the dot
## (playtest 2026-11-12). The whole crosshair moves with the aim offset (sway, the recoil the camera
## does not follow). When the aim is on something the weapon can damage within its range
## (show_target()), each arm gets a short cap across its outer end (a "T"). Melee and holstered: the
## dot only. Fills the screen; draws at its centre. The scope view draws the same crosshair
## (draw_crosshair(), ScopeOverlay).

const COLOR := Color(1, 1, 1, 0.9)
## The thin dark edge around the arms and the dot (OUTLINE px each side): reads on a bright wall.
const SHADOW := Color(0, 0, 0, 0.5)
## Arm and cap length (pixels at a 1080 px tall viewport; they scale with its height).
const ARM_LENGTH_1080: float = 11.0
const CAP_LENGTH_1080: float = 7.0
## Arm thickness at 1080 px (scales with the height, never under MIN_WIDTH).
const ARM_WIDTH_1080: float = 1.0
const MIN_WIDTH: float = 1.0
## Dark edge on each side of an arm and around the dot (pixels).
const OUTLINE: float = 0.5
## Dot radius at 1080 px (scales, never under MIN_DOT_RADIUS).
const DOT_RADIUS_1080: float = 1.0
const MIN_DOT_RADIUS: float = 1.0
## The arms' inner ends never come closer to the aim point than this (pixels at 1080 px; scaled), so
## a cone of radius 0 (a Master standing still) keeps a crosshair, clear of the dot.
const MIN_GAP_1080: float = 5.0
const REFERENCE_HEIGHT: float = 1080.0

## Cone radius in pixels (the arms' inner ends, at least the minimum gap).
var radius: float = 0.0
## Offset of the aim point from the screen centre in pixels.
var offset: Vector2 = Vector2.ZERO
## A ranged weapon is out: the arms show (else the dot only).
var ranged: bool = false
## The aim is on a target in range: the arms get their caps.
var on_target: bool = false
## Colour of the arms and caps on a target. The hook for colouring by hostility (factions, later):
## the HUD passes it to show_target(); white for now.
var target_color: Color = COLOR


## The cone `p_radius` (pixels) at `p_offset` from the centre; `p_ranged`: a ranged weapon is out.
func show_cone(p_radius: float, p_offset: Vector2, p_ranged: bool) -> void:
	if is_equal_approx(p_radius, radius) and p_offset.is_equal_approx(offset) and p_ranged == ranged:
		return
	radius = p_radius
	offset = p_offset
	ranged = p_ranged
	queue_redraw()


## Caps on the arms while the aim is on a target (`color`: the target's colour hook).
func show_target(p_on_target: bool, color: Color = COLOR) -> void:
	if p_on_target == on_target and color == target_color:
		return
	on_target = p_on_target
	target_color = color
	queue_redraw()


## Length of an arm in pixels at the current height.
func arm_length() -> float:
	return ARM_LENGTH_1080 * scale_for(size.y)


## Thickness of an arm in pixels at the current height.
func arm_width() -> float:
	return arm_width_for(size.y)


## The aim point: the centre moved by the offset, on a pixel centre (crisp 1 px arms).
func aim_point() -> Vector2:
	return snap(size * 0.5 + offset)


## Inner and outer end of each arm (pixels): up, down, left, right. Empty without a ranged weapon.
func arm_segments() -> Array[PackedVector2Array]:
	if not ranged:
		return [] as Array[PackedVector2Array]
	return arms(aim_point(), radius, size.y)


## Whether `collider` is something a weapon can damage: a character's hitbox, or an entity with
## BodyParts or Breakable (components, never names).
static func is_target(collider: Node) -> bool:
	if collider == null:
		return false
	if not Hitboxes.part_of(collider).is_empty():
		return true
	return BodyParts.of(collider) != null or Breakable.of(collider) != null


## Pixel sizes scale with the viewport height (1 at 1080 px).
static func scale_for(height: float) -> float:
	return maxf(height, 1.0) / REFERENCE_HEIGHT


static func arm_width_for(height: float) -> float:
	return maxf(ARM_WIDTH_1080 * scale_for(height), MIN_WIDTH)


## Distance from the aim point to the arms' inner ends for a cone of `cone_radius` px: never under
## the minimum gap.
static func inner_radius(cone_radius: float, height: float) -> float:
	return maxf(cone_radius, MIN_GAP_1080 * scale_for(height))


## `point` moved onto the centre of its pixel.
static func snap(point: Vector2) -> Vector2:
	return point.floor() + Vector2(0.5, 0.5)


## The four arms around `aim` for a cone of `cone_radius` px on a viewport `height` px tall.
static func arms(aim: Vector2, cone_radius: float, height: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var inner := inner_radius(cone_radius, height)
	var outer := inner + ARM_LENGTH_1080 * scale_for(height)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		result.append(PackedVector2Array([aim + direction * inner, aim + direction * outer]))
	return result


## Draws the crosshair on `canvas` around `aim`: the dot, and with `with_arms` the four arms on
## `cone_radius` (caps with `caps`, arms and caps in `color`). The HUD reticle and the scope view.
static func draw_crosshair(
	canvas: CanvasItem, aim: Vector2, cone_radius: float, height: float, with_arms: bool, caps: bool, color: Color
) -> void:
	var dot := maxf(DOT_RADIUS_1080 * scale_for(height), MIN_DOT_RADIUS)
	canvas.draw_circle(aim, dot + OUTLINE, SHADOW, true, -1.0, true)
	canvas.draw_circle(aim, dot, COLOR, true, -1.0, true)
	if not with_arms:
		return
	var width := arm_width_for(height)
	var cap := CAP_LENGTH_1080 * scale_for(height) * 0.5
	var bars: Array[PackedVector2Array] = []
	for arm in arms(aim, cone_radius, height):
		bars.append(arm)
		if caps:
			var along := (arm[1] - arm[0]).normalized()
			var across := Vector2(-along.y, along.x) * cap
			bars.append(PackedVector2Array([arm[1] - across, arm[1] + across]))
	# Every edge first, then every bar: no edge crosses a bar where a cap meets its arm.
	for bar in bars:
		var along := (bar[1] - bar[0]).normalized()
		canvas.draw_line(bar[0] - along * OUTLINE, bar[1] + along * OUTLINE, SHADOW, width + OUTLINE * 2.0, true)
	for bar in bars:
		canvas.draw_line(bar[0], bar[1], color, width, true)


func _draw() -> void:
	draw_crosshair(self, aim_point(), radius, size.y, ranged, on_target, target_color if on_target else COLOR)
