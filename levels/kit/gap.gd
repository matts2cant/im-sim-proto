@tool
class_name Gap
extends KitPart
## Two platforms of equal height with a pit between them, for jump tests.
## Origin: ground level, centre of the near platform's near edge. The track runs towards -Z:
## near platform z 0 to -length, gap, far platform from -(length + gap_width) to
## -(2 * length + gap_width). Platform tops are at `platform_height`; the pit floor is
## `pit_depth` below them (the ground when equal, a slab otherwise).
## Chain gaps by placing the next Gap at the far platform's near edge with `near_platform` off.
## The read-only `difficulty` label comes from the jump distances in metrics.md.

enum Difficulty { WALK_JUMP, BETWEEN_WALK_AND_SPRINT, SPRINT_JUMP, BETWEEN_SPRINT_AND_IMPASSABLE, IMPASSABLE }

## "Easy" gaps: a walk jump (~2.6 m) clears them with margin.
const WALK_MAX := 2.0
## "Hard" gaps: a walk jump fails, a sprint jump (~3.8 m) clears them.
const SPRINT_MIN := 3.0
const SPRINT_MAX := 3.5
## Impassable without augmentations.
const IMPASSABLE_MIN := 4.2
const PIT_FLOOR_THICKNESS := 0.2
const DIFFICULTY_NAMES: Array[String] = [
	"walk-jump", "between walk and sprint", "sprint-jump", "between sprint and impassable", "impassable"
]

@export_range(0.5, 10.0, 0.1, "or_greater", "suffix:m") var gap_width := 2.0:
	set(value):
		gap_width = value
		rebuild()
## Length of each platform along the track.
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var length := 4.0:
	set(value):
		length = value
		rebuild()
## Track width along x.
@export_range(0.8, 50.0, 0.1, "or_greater", "suffix:m") var width := 4.0:
	set(value):
		width = value
		rebuild()
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m") var platform_height := 2.0:
	set(value):
		platform_height = value
		rebuild()
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var pit_depth := 2.0:
	set(value):
		pit_depth = value
		rebuild()
## Off when chaining: the previous Gap's far platform is this one's near platform.
@export var near_platform := true:
	set(value):
		near_platform = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var surface := "concrete":
	set(value):
		surface = value
		rebuild()
## Informational sign text, e.g. "2 m: walk-jump".
@export var difficulty_label := "":
	get:
		return label_for(_gap())
	set(_value):
		pass


static func difficulty_for(gap: float) -> Difficulty:
	if gap <= WALK_MAX:
		return Difficulty.WALK_JUMP
	if gap < SPRINT_MIN:
		return Difficulty.BETWEEN_WALK_AND_SPRINT
	if gap <= SPRINT_MAX:
		return Difficulty.SPRINT_JUMP
	if gap < IMPASSABLE_MIN:
		return Difficulty.BETWEEN_SPRINT_AND_IMPASSABLE
	return Difficulty.IMPASSABLE


## "<gap> m: <difficulty>", the text used on gap signs.
static func label_for(gap: float) -> String:
	var metres := ("%.2f" % gap).rstrip("0").rstrip(".")
	return "%s m: %s" % [metres, DIFFICULTY_NAMES[difficulty_for(gap)]]


func get_difficulty() -> Difficulty:
	return difficulty_for(_gap())


func _validate_property(property: Dictionary) -> void:
	if property.name == "difficulty_label":
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _gap() -> float:
	return clampf(gap_width, 0.5, 10.0)


func _surface_name() -> String:
	return surface if GrayboxMaterials.is_surface(surface) else GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	var gap := _clamped("Gap width", gap_width, 0.5, 10.0)
	var l := _clamped("Length", length, 0.5, 50.0)
	var w := _clamped("Width", width, 0.8, 50.0)
	var top := _clamped("Platform height", platform_height, 0.0, 20.0)
	var pit := _clamped("Pit depth", pit_depth, 0.5, 50.0)
	var difficulty := difficulty_for(gap)
	if difficulty in [Difficulty.BETWEEN_WALK_AND_SPRINT, Difficulty.BETWEEN_SPRINT_AND_IMPASSABLE]:
		_warn(
			(
				"Gap %s m is %s: use <= 2 m (walk-jump), 3-3.5 m (sprint-jump) or >= 4.2 m (impassable)."
				% [gap, DIFFICULTY_NAMES[difficulty]]
			)
		)
	var material := GrayboxMaterials.for_surface(_checked_surface(surface))
	var pit_bottom := top - pit
	var bottom := minf(0.0, pit_bottom)
	var size := Vector3(w, top - bottom, l)
	var y := (top + bottom) * 0.5
	if near_platform:
		_add_box("NearPlatform", size, Vector3(0.0, y, -l * 0.5), material)
	_add_box("FarPlatform", size, Vector3(0.0, y, -l * 1.5 - gap), material)
	if absf(pit_bottom) > 0.001:
		# The pit floor is a slab between the platforms, unless the ground already is.
		var slab_bottom := 0.0 if pit_bottom > 0.0 else pit_bottom - PIT_FLOOR_THICKNESS
		var slab := Vector3(w, pit_bottom - slab_bottom, gap)
		_add_box("PitFloor", slab, Vector3(0.0, (pit_bottom + slab_bottom) * 0.5, -l - gap * 0.5), material)
