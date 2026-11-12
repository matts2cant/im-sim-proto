class_name ImpactMarks
extends Node3D
## Component (ADR 0125): any surface entity that keeps a small mark where each ray hit it, so a
## spray's pattern stays readable (the shooting range's spray wall). The entity's StimulusReceiver
## carries a receptron whose MarkImpactEffect calls add_mark() with the hit's position and normal
## (`objects/components/receptrons/marked_by_bullets.tres`: `damage.ballistic`). The marks are one
## MultiMesh of small quads, `offset` off the surface; past `max_marks` the oldest is reused. Visual
## only and not saved (like a muzzle flash): a reload starts with a clean surface.

@export_range(1, 2000) var max_marks: int = 500
## Edge of a mark (metres).
@export var mark_size: float = 0.03
@export var mark_color: Color = Color(0.08, 0.08, 0.09)
## Distance off the surface along its normal, so the mark never z-fights with it.
@export var offset: float = 0.003

## Marks added since the last clear (also counts the ones the cap replaced).
var added: int = 0

var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
# The marks' points by slot (the MultiMesh is write-only on a headless renderer).
var _points: Array[Vector3] = []


func _ready() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(mark_size, mark_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = mark_color
	quad.material = material
	_multimesh.mesh = quad
	_multimesh.instance_count = max_marks
	_multimesh.visible_instance_count = 0
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Marks"
	_instance.multimesh = _multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Marks are placed in world space.
	_instance.top_level = true
	add_child(_instance)


## The ImpactMarks child of `entity`, or null.
static func of(entity: Node) -> ImpactMarks:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is ImpactMarks:
			return child as ImpactMarks
	return null


## Leaves a mark at `point` (world) on a surface facing `normal`; the oldest goes past the cap.
func add_mark(point: Vector3, normal: Vector3) -> void:
	var facing := normal.normalized() if not normal.is_zero_approx() else Vector3.BACK
	var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(-facing, up)
	var slot := added % max_marks
	_multimesh.set_instance_transform(slot, Transform3D(basis, point + facing * offset))
	if slot < _points.size():
		_points[slot] = point
	else:
		_points.append(point)
	added += 1
	_multimesh.visible_instance_count = count()


## Removes every mark.
func clear() -> void:
	added = 0
	_points.clear()
	_multimesh.visible_instance_count = 0


## Marks shown now (at most `max_marks`).
func count() -> int:
	return mini(added, max_marks)


## World positions of the marks shown, oldest first (tests, the range's stats).
func points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var shown := count()
	var first := added - shown
	for i in shown:
		result.append(_points[(first + i) % max_marks])
	return result
