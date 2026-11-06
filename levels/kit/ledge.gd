@tool
class_name Ledge
extends KitPart
## A solid block whose top is a ledge `height` above the ground (design/levels/metrics.md).
## Origin: bottom centre of the lip face. The lip (front face) is at z = 0 and faces +Z;
## the block extends `depth` towards -Z. The read-only `band` names what the player can do.

## Walk-up steps (StepClimber step height 0.35 m with margin, ADR 0058).
const STEP_MAX := 0.3
const JUMP_UP_MIN := 0.35
const JUMP_UP_BELOW := 1.0
const MANTLE_MAX := 1.9
const NO_MANTLE_MIN := 2.0
const NO_MANTLE_MAX := 2.2
const OUT_OF_REACH_MIN := 2.3

@export_range(0.05, 20.0, 0.05, "or_greater", "suffix:m") var height := 1.5:
	set(value):
		height = value
		rebuild()
## Lip length along x.
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:m") var width := 2.5:
	set(value):
		width = value
		rebuild()
## Top depth along -z.
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:m") var depth := 3.0:
	set(value):
		depth = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var surface := "concrete":
	set(value):
		surface = value
		rebuild()
## Informational: "step up", "jump up", "mantle", "deliberate no", "out of reach" or "between bands".
@export var band := "":
	get:
		return band_for(height)
	set(_value):
		pass


## Metric band of a ledge height (metrics.md, Traversal).
static func band_for(ledge_height: float) -> String:
	if ledge_height <= STEP_MAX:
		return "step up"
	if ledge_height < JUMP_UP_MIN:
		return "between bands"
	if ledge_height < JUMP_UP_BELOW:
		return "jump up"
	if ledge_height <= MANTLE_MAX:
		return "mantle"
	if ledge_height >= NO_MANTLE_MIN and ledge_height <= NO_MANTLE_MAX:
		return "deliberate no"
	if ledge_height >= OUT_OF_REACH_MIN:
		return "out of reach"
	return "between bands"


func _validate_property(property: Dictionary) -> void:
	if property.name == "band":
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _surface_name() -> String:
	return surface if GrayboxMaterials.is_surface(surface) else GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	var h := _clamped("Height", height, 0.05, 20.0)
	var w := _clamped("Width", width, 0.1, 50.0)
	var d := _clamped("Depth", depth, 0.1, 50.0)
	if band_for(h) == "between bands":
		_warn(
			(
				(
					"Height %s m is between metric bands: use <= 0.3 (step up), 0.35-1.0 (jump up), "
					+ "1.0-1.9 (mantle), 2.0-2.2 (deliberate no) or >= 2.3 (out of reach)."
				)
				% h
			)
		)
	var material := GrayboxMaterials.for_surface(_checked_surface(surface))
	_add_box("Block", Vector3(w, h, d), Vector3(0.0, h * 0.5, -d * 0.5), material)
