@tool
class_name KitPart
extends CSGCombiner3D
## Base of the graybox kit parts (ADR 0042). The part itself is the CSG root: it has collision
## and carries the `surface` metadata the player's footsteps read (ADR 0033).
## Geometry is generated as internal CSG children (not saved, not duplicated, hidden in the
## editor tree) and rebuilt whenever an exported property changes. Out-of-range values are
## clamped for the geometry and reported by `_get_configuration_warnings()`; the stored value is
## kept so the warning stays visible until it is fixed.

const SURFACE_META: StringName = &"surface"
## The material of the part's walls when it differs from its floor's (a Room; bullet impacts read
## it on wall faces, ShotFxConfig, ADR 0126).
const WALL_SURFACE_META: StringName = &"wall_surface"
## Extra length on subtracted shapes so cuts never leave coplanar slivers.
const CUT_MARGIN := 0.05

var _generated: Array[Node] = []
var _warnings: PackedStringArray = []


func _init() -> void:
	use_collision = true
	# Level geometry is the world layer (ADR 0045): it blocks line-of-sight stimuli (fire).
	collision_layer = PhysicsLayers.WORLD
	rebuild()


## Regenerates the part's CSG children and warnings from its current properties.
func rebuild() -> void:
	for node: Node in _generated:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_generated.clear()
	_warnings = PackedStringArray()
	set_meta(SURFACE_META, StringName(_surface_name()))
	var wall := _wall_surface_name()
	if wall.is_empty():
		remove_meta(WALL_SURFACE_META)
	else:
		set_meta(WALL_SURFACE_META, StringName(wall))
	_build()
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return _warnings


## Overridden by parts: adds the CSG children through `_add_box` and friends.
func _build() -> void:
	pass


## Overridden by parts: the floor surface written to the `surface` metadata.
func _surface_name() -> String:
	return GrayboxMaterials.DEFAULT_SURFACE


## Overridden by parts with walls of another material than their floor: written to the
## `wall_surface` metadata ("" : none).
func _wall_surface_name() -> String:
	return ""


func _warn(message: String) -> void:
	_warnings.append(message)


## `value` limited to [min_value, max_value]; warns with `label` when it had to be clamped.
func _clamped(label: String, value: float, min_value: float, max_value: float, unit: String = " m") -> float:
	var result := clampf(value, min_value, max_value)
	if not is_equal_approx(result, value):
		_warn(
			"%s %s%s is outside %s-%s%s; using %s%s." % [label, value, unit, min_value, max_value, unit, result, unit]
		)
	return result


## Surface name checked against the known surfaces (warns and falls back to concrete).
func _checked_surface(surface: String) -> String:
	if GrayboxMaterials.is_surface(surface):
		return surface
	_warn(
		(
			"Unknown surface '%s' (use one of %s); using %s."
			% [surface, ", ".join(GrayboxMaterials.SURFACES), GrayboxMaterials.DEFAULT_SURFACE]
		)
	)
	return GrayboxMaterials.DEFAULT_SURFACE


func _add_box(
	node_name: String,
	size: Vector3,
	center: Vector3,
	material: Material,
	operation: CSGShape3D.Operation = CSGShape3D.OPERATION_UNION,
	basis: Basis = Basis.IDENTITY,
) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.transform = Transform3D(basis, center)
	box.material = material
	box.operation = operation
	_add_generated(box)
	return box


func _add_generated(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_generated.append(node)
