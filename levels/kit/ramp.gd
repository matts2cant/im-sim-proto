@tool
class_name Ramp
extends KitPart
## A solid wedge ramp (ADR 0034: ramps instead of stair steps), at most 40 degrees.
## Origin: bottom centre of the low edge. The ramp rises towards -Z: its top edge is at
## (0, rise, -run), where a Ledge or platform of height `rise` with its lip at z = -run fits.

const MAX_ANGLE_DEG := 40.0

@export_range(0.05, 20.0, 0.05, "or_greater", "suffix:m") var rise := 1.0:
	set(value):
		rise = value
		rebuild()
@export_range(0.1, 50.0, 0.05, "or_greater", "suffix:m") var run := 2.0:
	set(value):
		run = value
		rebuild()
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var width := 2.0:
	set(value):
		width = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var surface := "concrete":
	set(value):
		surface = value
		rebuild()


## Slope of the built ramp in degrees (after clamping).
func angle_deg() -> float:
	return rad_to_deg(atan2(built_rise(), _run()))


## Rise actually built: `rise`, lowered when it would make the slope steeper than 40 degrees.
func built_rise() -> float:
	var r := clampf(rise, 0.05, 20.0)
	return minf(r, _run() * tan(deg_to_rad(MAX_ANGLE_DEG)))


func _run() -> float:
	return clampf(run, 0.1, 50.0)


func _surface_name() -> String:
	return surface if GrayboxMaterials.is_surface(surface) else GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	var r := _clamped("Rise", rise, 0.05, 20.0)
	var length := _clamped("Run", run, 0.1, 50.0)
	var w := _clamped("Width", width, 0.5, 50.0)
	var built := built_rise()
	if built < r - 0.0001:
		_warn(
			(
				"Slope %.1f deg is steeper than %d deg (metrics.md); rise clamped to %.2f m."
				% [rad_to_deg(atan2(r, length)), MAX_ANGLE_DEG, built]
			)
		)
	var wedge := CSGPolygon3D.new()
	wedge.name = "Wedge"
	# Profile in the polygon's XY plane (x = distance along -Z), extruded along its -Z.
	# Turning it 90 degrees about Y maps its +X to -Z and its extrusion to -X.
	wedge.polygon = PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, built)])
	wedge.depth = w
	wedge.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0.0, 0.0))
	wedge.material = GrayboxMaterials.for_surface(_checked_surface(surface))
	_add_generated(wedge)
