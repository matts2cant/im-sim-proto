class_name ImpactMarks
extends Node3D
## Component (ADR 0125): any surface entity that keeps a small mark where each ray hit it, so a
## spray's pattern stays readable (the shooting range's spray wall). The entity's StimulusReceiver
## carries a receptron whose MarkImpactEffect calls add_mark() with the hit's position and normal
## (`objects/components/receptrons/marked_by_bullets.tres`: `damage.ballistic`). The marks are one
## MultiMesh of small quads, `offset` off the surface; past `max_marks` the oldest is reused. Visual
## only and not saved (like a muzzle flash): a reload starts with a clean surface.
## The world's bullet holes (ShotFx, ADR 0126) are ImpactMarks too: each mark its own size and colour
## (add_mark()), an optional `texture` (a round hole, a crack star), and with `fade_after` > 0 a mark
## fades out over `fade_time` once it is that old (step()).

@export_range(1, 2000) var max_marks: int = 500
## Edge of a mark (metres).
@export var mark_size: float = 0.03
@export var mark_color: Color = Color(0.08, 0.08, 0.09)
## Distance off the surface along its normal, so the mark never z-fights with it.
@export var offset: float = 0.003
## Seconds a mark stays fully visible before it fades; 0: marks never fade.
@export var fade_after: float = 0.0
## Seconds the fade takes.
@export var fade_time: float = 3.0
## Texture of a mark (alpha-blended); null: a plain square.
@export var texture: Texture2D

## Marks added since the last clear (also counts the ones the cap replaced).
var added: int = 0

var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
# The marks' points by slot (the MultiMesh is write-only on a headless renderer).
var _points: Array[Vector3] = []
# Each slot's colour and age (s), for the fade.
var _colors: Array[Color] = []
var _ages: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(mark_size, mark_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	# Instance colours are given like albedo colours (sRGB).
	material.vertex_color_is_srgb = true
	if texture != null or fade_after > 0.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = texture
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
	set_process(fade_after > 0.0)


func _process(delta: float) -> void:
	step(delta)


## The ImpactMarks child of `entity`, or null.
static func of(entity: Node) -> ImpactMarks:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is ImpactMarks:
			return child as ImpactMarks
	return null


## Leaves a mark at `point` (world) on a surface facing `normal`; the oldest goes past the cap.
## `size` (edge, m) and `color` override `mark_size` and `mark_color` when given (> 0, alpha > 0);
## a sized mark is turned at random about the normal so repeated holes do not look stamped.
func add_mark(point: Vector3, normal: Vector3, size: float = 0.0, color: Color = Color.TRANSPARENT) -> void:
	var facing := normal.normalized() if not normal.is_zero_approx() else Vector3.BACK
	var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(-facing, up)
	if size > 0.0:
		basis = basis.rotated(facing, _rng.randf() * TAU).scaled_local(Vector3.ONE * (size / mark_size))
	var tint := color if color.a > 0.0 else mark_color
	var slot := added % max_marks
	_multimesh.set_instance_transform(slot, Transform3D(basis, point + facing * offset))
	_multimesh.set_instance_color(slot, tint)
	if slot < _points.size():
		_points[slot] = point
		_colors[slot] = tint
		_ages[slot] = 0.0
	else:
		_points.append(point)
		_colors.append(tint)
		_ages.append(0.0)
	added += 1
	_multimesh.visible_instance_count = count()


## Ages every mark by `delta` seconds and fades those past `fade_after` (no-op when they never fade).
func step(delta: float) -> void:
	if fade_after <= 0.0:
		return
	for slot in _ages.size():
		var was := _ages[slot]
		_ages[slot] = was + delta
		# Only marks inside (or just past) their fade change colour.
		if _ages[slot] >= fade_after and was <= fade_after + fade_time:
			var tint := _colors[slot]
			tint.a *= opacity(slot)
			_multimesh.set_instance_color(slot, tint)


## Opacity of the mark in `slot`: 1 until `fade_after`, then down to 0 over `fade_time`.
func opacity(slot: int) -> float:
	if fade_after <= 0.0 or slot < 0 or slot >= _ages.size():
		return 1.0
	return clampf(1.0 - (_ages[slot] - fade_after) / maxf(fade_time, 0.001), 0.0, 1.0)


## Removes every mark.
func clear() -> void:
	added = 0
	_points.clear()
	_colors.clear()
	_ages.clear()
	_multimesh.visible_instance_count = 0


## Marks shown now (at most `max_marks`; faded marks count until their slot is reused).
func count() -> int:
	return mini(added, max_marks)


## Marks not yet faded out.
func visible_count() -> int:
	var shown := 0
	for slot in mini(_ages.size(), count()):
		if opacity(slot) > 0.0:
			shown += 1
	return shown


## World positions of the marks shown, oldest first (tests, the range's stats).
func points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var shown := count()
	var first := added - shown
	for i in shown:
		result.append(_points[(first + i) % max_marks])
	return result
