class_name ScopeOverlay
extends Control
## HUD scope view (ADR 0085), shown instead of the reticle while the player is scoped: black outside
## a round lens and, at the lens centre, the HUD's crosshair (Reticle.draw_crosshair(): arms on the
## scoped aim cone, the same AimModel.reticle_radius at the scope's field of view, the minimum gap,
## caps on a target in range). The aim offset (sway, recoil) moves the lens and the crosshair
## together, so they are concentric in every frame (playtest 2026-11-12). Thin duplex lines run from
## the lens edge towards the centre and stop short of the arms' outer ends. A shot blacks the lens
## out for a moment (show_blackout()). Fills the screen.

const BLACK := Color(0, 0, 0, 1)
const LINE := Color(0.05, 0.05, 0.05, 0.95)
## Lens radius as a share of the viewport height.
const LENS_SHARE: float = 0.46
const SEGMENTS: int = 96
## Space between the duplex lines' inner ends and the arms' outer ends (pixels at 1080 px; scaled).
const LINE_GAP_1080: float = 8.0

## Aim cone radius in pixels.
var radius: float = 0.0
## Offset of the aim point from the screen centre in pixels (sway, recoil).
var offset: Vector2 = Vector2.ZERO
## A ranged weapon is out (always, while scoped): the crosshair has its arms.
var ranged: bool = true
## The aim is on a target in range: the arms get their caps (Reticle.show_target()).
var on_target: bool = false
## Opacity (0-1) of the black cover over the lens after a shot (RecoilState.blackout()).
var blackout: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_cone(p_radius: float, p_offset: Vector2, p_ranged: bool = true) -> void:
	if is_equal_approx(p_radius, radius) and p_offset.is_equal_approx(offset) and p_ranged == ranged:
		return
	radius = p_radius
	offset = p_offset
	ranged = p_ranged
	queue_redraw()


func show_target(p_on_target: bool) -> void:
	if p_on_target == on_target:
		return
	on_target = p_on_target
	queue_redraw()


## The lens blacks out after a shot: `amount` 1 is black, 0 clear (ADR 0123).
func show_blackout(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(amount, blackout):
		return
	blackout = amount
	queue_redraw()


## Radius of the lens in pixels.
func lens_radius() -> float:
	return size.y * LENS_SHARE


## Centre of the lens: the screen centre moved by the aim offset (on a pixel centre).
func lens_centre() -> Vector2:
	return Reticle.snap(size * 0.5 + offset)


## Centre of the crosshair: always the lens centre.
func crosshair_centre() -> Vector2:
	return lens_centre()


## The crosshair's arms (inner and outer ends, pixels): up, down, left, right.
func arm_segments() -> Array[PackedVector2Array]:
	if not ranged:
		return [] as Array[PackedVector2Array]
	return Reticle.arms(crosshair_centre(), radius, size.y)


## The duplex lines (from, to): from the lens edge to short of the arms' outer ends; none when the
## arms reach that far.
func line_segments() -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var centre := crosshair_centre()
	var lens := lens_radius()
	var pixel := Reticle.scale_for(size.y)
	var reach := Reticle.ARM_LENGTH_1080 + LINE_GAP_1080
	var inner := Reticle.inner_radius(radius, size.y) + reach * pixel
	if inner >= lens:
		return lines
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		lines.append(PackedVector2Array([centre + direction * lens, centre + direction * inner]))
	return lines


func _draw() -> void:
	var centre := lens_centre()
	var lens := lens_radius()
	# Black everywhere but the lens: one thick ring from the lens edge out past the screen corners
	# (wherever the offset moved the lens).
	var outer := size.length() * 0.5 + offset.length() + 4.0
	draw_arc(centre, (lens + outer) * 0.5, 0.0, TAU, SEGMENTS, BLACK, outer - lens + 2.0)
	draw_arc(centre, lens, 0.0, TAU, SEGMENTS, BLACK, 3.0, true)
	for line in line_segments():
		draw_line(line[0], line[1], LINE, 1.0)
	Reticle.draw_crosshair(self, centre, radius, size.y, ranged, on_target, Reticle.COLOR)
	if blackout > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, blackout))
