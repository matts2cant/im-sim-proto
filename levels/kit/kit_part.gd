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
## Extra length on subtracted shapes so cuts never leave coplanar slivers.
const CUT_MARGIN := 0.05

var _generated: Array[Node] = []
var _warnings: PackedStringArray = []


func _init() -> void:
	use_collision = true
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
