@tool
class_name Stairs
extends KitPart
## A straight flight of steps (design/levels/metrics.md: risers <= 0.3 m, stairs >= 1.2 m wide).
## Origin: bottom centre of the first riser, on the lower floor. The flight climbs towards -Z:
## step k (1..n) spans z from -(k - 1) x tread to -k x tread and its top is k x riser, so the last
## step is level with the upper floor at z = -run (run = n x tread). n = ceil(rise / max_riser).
## `solid` fills every step down to the lower floor (a stair against a wall or on the ground);
## otherwise each step is a `thickness` deep block, a free-standing steel flight with a stepped
## underside you can walk beneath. Walk-up risers are on the navmesh (max climb 0.3 m, ADR 0058).

## Metric limits: walk-up riser maximum (StepClimber 0.35 m with margin) and comfortable minimums.
const RISER_LIMIT := 0.3
const MIN_WIDTH := 1.2
const MIN_TREAD := 0.25
const MAX_SLOPE_DEG := 40.0

## Total height from the lower floor to the upper floor.
@export_range(0.05, 30.0, 0.01, "or_greater", "suffix:m") var rise := 1.0:
	set(value):
		rise = value
		rebuild()
@export_range(0.1, 20.0, 0.05, "or_greater", "suffix:m") var width := 1.2:
	set(value):
		width = value
		rebuild()
@export_range(0.1, 1.0, 0.01, "suffix:m") var tread := 0.3:
	set(value):
		tread = value
		rebuild()
## Highest riser allowed; the flight uses equal risers of at most this height.
@export_range(0.05, 0.3, 0.01, "suffix:m") var max_riser := 0.18:
	set(value):
		max_riser = value
		rebuild()
@export var solid := true:
	set(value):
		solid = value
		rebuild()
## Depth of each step block below its top when not `solid`.
@export_range(0.05, 2.0, 0.01, "suffix:m") var thickness := 0.3:
	set(value):
		thickness = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var surface := "concrete":
	set(value):
		surface = value
		rebuild()


## Number of risers (and treads).
func steps() -> int:
	var r := clampf(rise, 0.05, 30.0)
	return maxi(1, ceili(r / clampf(max_riser, 0.05, RISER_LIMIT) - 0.0001))


## Height of one riser.
func riser() -> float:
	return clampf(rise, 0.05, 30.0) / steps()


## Horizontal length of the flight: the top step ends at z = -run().
func run() -> float:
	return steps() * clampf(tread, 0.1, 1.0)


func _surface_name() -> String:
	return surface if GrayboxMaterials.is_surface(surface) else GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	_clamped("Rise", rise, 0.05, 30.0)
	_clamped("Max riser", max_riser, 0.05, RISER_LIMIT)
	var w := _clamped("Width", width, 0.1, 20.0)
	var t := _clamped("Tread", tread, 0.1, 1.0)
	var depth := _clamped("Thickness", thickness, 0.05, 2.0)
	if w < MIN_WIDTH:
		_warn("Width %s m is below the %s m stair minimum." % [w, MIN_WIDTH])
	if t < MIN_TREAD:
		_warn("Tread %s m is below %s m: steps are hard to read." % [t, MIN_TREAD])
	var n := steps()
	var r := riser()
	if rad_to_deg(atan2(r, t)) > MAX_SLOPE_DEG:
		_warn("Pitch %.0f deg is steeper than %s deg." % [rad_to_deg(atan2(r, t)), MAX_SLOPE_DEG])
	var material := GrayboxMaterials.for_surface(_checked_surface(surface))
	for k in range(1, n + 1):
		var top := k * r
		var bottom := 0.0 if solid else maxf(0.0, top - maxf(depth, r))
		_add_box(
			"Step%d" % k,
			Vector3(w, top - bottom, t),
			Vector3(0.0, (top + bottom) * 0.5, -(k - 0.5) * t),
			material,
		)
