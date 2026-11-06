@tool
class_name VentSegment
extends KitPart
## A metal crawl duct segment: 1.2 m wide inside, 1.0-1.2 m high (crouch only, metrics.md).
## Connection points (ADR 0042): the origin is the centre of the interior floor at the entry
## opening and the segment runs towards -Z. `exit_transform()` is the next segment's transform
## relative to this one, so `next.transform = transform * exit_transform()` snaps them:
##   STRAIGHT      exit at (0, -drop, -length), same heading
##   CORNER_LEFT   exit at (-0.6, 0, -0.6), heading -X (turned +90 degrees about Y)
##   CORNER_RIGHT  exit at (0.6, 0, -0.6), heading +X (turned -90 degrees about Y)
## Housing walls are 0.2 m thick. `fill_below` makes the housing solid down to that depth below
## the entry floor (a vent through a block or wall, nothing to crawl under).

enum Kind { STRAIGHT, CORNER_LEFT, CORNER_RIGHT }

const INTERIOR_WIDTH := 1.2
const WALL := 0.2
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 1.2
const MAX_SLOPE_DEG := 40.0
const SURFACE := "metal"

@export var kind := Kind.STRAIGHT:
	set(value):
		kind = value
		rebuild()
## Straight segments only.
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var length := 2.0:
	set(value):
		length = value
		rebuild()
@export_range(1.0, 1.2, 0.05, "suffix:m") var interior_height := 1.1:
	set(value):
		interior_height = value
		rebuild()
## Straight segments only: how much lower the exit floor is than the entry floor (negative
## climbs). The slope is limited to 40 degrees.
@export_range(-20.0, 20.0, 0.05, "suffix:m") var drop := 0.0:
	set(value):
		drop = value
		rebuild()
@export_range(0.0, 20.0, 0.05, "or_greater", "suffix:m") var fill_below := 0.0:
	set(value):
		fill_below = value
		rebuild()


## Transform of the next segment's origin relative to this segment's origin.
func exit_transform() -> Transform3D:
	var half := INTERIOR_WIDTH * 0.5
	match kind:
		Kind.CORNER_LEFT:
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-half, 0.0, -half))
		Kind.CORNER_RIGHT:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(half, 0.0, -half))
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -_drop(), -_length()))


func _length() -> float:
	return clampf(length, 0.5, 50.0)


func _drop() -> float:
	var limit := _length() * tan(deg_to_rad(MAX_SLOPE_DEG))
	return clampf(drop, -limit, limit)


func _surface_name() -> String:
	return SURFACE


func _build() -> void:
	var h := _clamped("Interior height", interior_height, MIN_HEIGHT, MAX_HEIGHT)
	var fill := _clamped("Fill below", fill_below, 0.0, 20.0)
	var metal := GrayboxMaterials.for_surface(SURFACE)
	if kind == Kind.STRAIGHT:
		_build_straight(h, fill, metal)
	else:
		_build_corner(h, fill, metal)


func _build_straight(h: float, fill: float, metal: Material) -> void:
	var l := _clamped("Length", length, 0.5, 50.0)
	var d := _drop()
	if not is_equal_approx(d, drop):
		_warn("Drop %s m is steeper than %d deg over %s m; using %.2f m." % [drop, MAX_SLOPE_DEG, l, d])
	var outer := INTERIOR_WIDTH + WALL * 2.0
	if is_zero_approx(d):
		var bottom := -maxf(WALL, fill)
		var top := h + WALL
		_add_box("Housing", Vector3(outer, top - bottom, l), Vector3(0.0, (top + bottom) * 0.5, -l * 0.5), metal)
		_add_box(
			"Interior",
			Vector3(INTERIOR_WIDTH, h, l + CUT_MARGIN * 2.0),
			Vector3(0.0, h * 0.5, -l * 0.5),
			metal,
			CSGShape3D.OPERATION_SUBTRACTION
		)
		return
	# Sloped: tilted housing and interior, cut to vertical end faces at z = 0 and z = -l.
	var angle := atan2(d, l)
	var tilt := Basis(Vector3.RIGHT, -angle)
	var up := tilt * Vector3.UP
	var floor_mid := Vector3(0.0, -d * 0.5, -l * 0.5)
	var slant := l / cos(angle) + (h + WALL * 2.0) * absf(tan(angle)) * 2.0 + CUT_MARGIN * 2.0
	_add_box(
		"Housing",
		Vector3(outer, h + WALL * 2.0, slant),
		floor_mid + up * (h * 0.5),
		metal,
		CSGShape3D.OPERATION_UNION,
		tilt
	)
	if fill > 0.0:
		var low := -fill
		var high := maxf(0.0, -d) + h + WALL
		_add_box("Fill", Vector3(outer, high - low, l), Vector3(0.0, (high + low) * 0.5, -l * 0.5), metal)
	var clip_low := minf(minf(0.0, -d) - WALL, -fill) - 1.0
	var clip_high := maxf(0.0, -d) + h + WALL + 1.0
	_add_box(
		"EndClip",
		Vector3(outer + 1.0, clip_high - clip_low, l),
		Vector3(0.0, (clip_high + clip_low) * 0.5, -l * 0.5),
		metal,
		CSGShape3D.OPERATION_INTERSECTION
	)
	_add_box(
		"Interior",
		Vector3(INTERIOR_WIDTH, h, slant),
		floor_mid + up * (h * 0.5),
		metal,
		CSGShape3D.OPERATION_SUBTRACTION,
		tilt
	)


func _build_corner(h: float, fill: float, metal: Material) -> void:
	var half := INTERIOR_WIDTH * 0.5
	var side := -1.0 if kind == Kind.CORNER_LEFT else 1.0
	var bottom := -maxf(WALL, fill)
	var top := h + WALL
	var deep := INTERIOR_WIDTH + WALL
	# No wall on the exit side: the housing stops at the exit plane, where the next segment's
	# housing starts, so a sloped next segment meets a clean floor edge.
	var housing := Vector3(INTERIOR_WIDTH + WALL, top - bottom, deep)
	_add_box("Housing", housing, Vector3(-side * WALL * 0.5, (top + bottom) * 0.5, -deep * 0.5), metal)
	_add_box(
		"Interior",
		Vector3(INTERIOR_WIDTH, h, INTERIOR_WIDTH + CUT_MARGIN),
		Vector3(0.0, h * 0.5, (CUT_MARGIN - INTERIOR_WIDTH) * 0.5),
		metal,
		CSGShape3D.OPERATION_SUBTRACTION
	)
	# Side exit: from the interior centre out through the exit plane on the turning side.
	var reach := half + CUT_MARGIN
	_add_box(
		"Exit",
		Vector3(reach, h, INTERIOR_WIDTH),
		Vector3(side * reach * 0.5, h * 0.5, -half),
		metal,
		CSGShape3D.OPERATION_SUBTRACTION
	)
