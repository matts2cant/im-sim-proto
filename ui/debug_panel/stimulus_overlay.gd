class_name StimulusOverlay
extends MeshInstance3D
## Debug overlay: draws each processed RADIUS stimulus as a wire sphere and each propagation
## polyline (noise paths, ray hits) as lines, coloured by stimulus type, for `lifetime` seconds.
## Fed only by StimulusSystem.stimulus_processed; drawn unshaded and through walls.

const CIRCLE_SEGMENTS: int = 32
const TYPE_COLORS: Dictionary[StringName, Color] = {
	&"noise": Color(1.0, 0.85, 0.1),
	&"fire": Color(1.0, 0.45, 0.0),
	&"damage": Color(1.0, 0.1, 0.15),
}

## Seconds a stimulus stays visible.
@export var lifetime: float = 1.5

## Toggled by the Overlays tab's "Stimuli" checkbox.
var enabled: bool = false:
	set = set_enabled

var _drawings: Array[Drawing] = []
var _vertex_count: int = 0
var _immediate := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


class Drawing:
	extends RefCounted
	var color: Color
	var center: Vector3
	## <= 0: no sphere.
	var radius: float
	var paths: Array[PackedVector3Array]
	var age: float = 0.0


func _init() -> void:
	name = "StimulusOverlay"
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.render_priority = 10


## Colour for a stimulus type: fixed for noise/fire/damage (and their subtypes), hashed otherwise.
static func color_for(type: StringName) -> Color:
	for key: StringName in TYPE_COLORS:
		if TagContainer.matches(type, key):
			return TYPE_COLORS[key]
	return Color.from_hsv(float(hash(type) % 360) / 360.0, 0.7, 1.0)


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not StimulusSystem.stimulus_processed.is_connected(track):
		StimulusSystem.stimulus_processed.connect(track)
	elif not enabled and StimulusSystem.stimulus_processed.is_connected(track):
		StimulusSystem.stimulus_processed.disconnect(track)
	if not enabled:
		_drawings.clear()
		_redraw()


func track(stimulus: Stimulus, paths: Array[PackedVector3Array]) -> void:
	var drawing := Drawing.new()
	drawing.color = color_for(stimulus.type)
	drawing.center = stimulus.origin
	drawing.radius = stimulus.radius if stimulus.shape == Stimulus.Shape.RADIUS else 0.0
	drawing.paths = paths.filter(func(path: PackedVector3Array) -> bool: return path.size() >= 2)
	if drawing.radius <= 0.0 and drawing.paths.is_empty():
		return  # CONTACT: nothing to draw (and an empty surface is an error).
	_drawings.append(drawing)
	_redraw()


## Number of stimuli currently drawn.
func active_count() -> int:
	return _drawings.size()


## Line vertices in the current mesh (two per segment).
func vertex_count() -> int:
	return _vertex_count


func _process(delta: float) -> void:
	if not _drawings.is_empty():
		advance(delta)


## Ages the drawings by `delta` seconds and drops expired ones.
func advance(delta: float) -> void:
	for drawing in _drawings:
		drawing.age += delta
	_drawings = _drawings.filter(func(drawing: Drawing) -> bool: return drawing.age < lifetime)
	_redraw()


func _redraw() -> void:
	_immediate.clear_surfaces()
	_vertex_count = 0
	if _drawings.is_empty():
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for drawing in _drawings:
		_immediate.surface_set_color(drawing.color)
		if drawing.radius > 0.0:
			_add_wire_sphere(drawing.center, drawing.radius)
		for path in drawing.paths:
			for i in range(1, path.size()):
				_add_line(path[i - 1], path[i])
	_immediate.surface_end()


func _add_wire_sphere(center: Vector3, radius: float) -> void:
	var axes: Array[Array] = [
		[Vector3.RIGHT, Vector3.FORWARD], [Vector3.RIGHT, Vector3.UP], [Vector3.UP, Vector3.FORWARD]
	]
	for pair in axes:
		var u: Vector3 = pair[0]
		var v: Vector3 = pair[1]
		for i in CIRCLE_SEGMENTS:
			var a := TAU * i / CIRCLE_SEGMENTS
			var b := TAU * (i + 1) / CIRCLE_SEGMENTS
			_add_line(center + (u * cos(a) + v * sin(a)) * radius, center + (u * cos(b) + v * sin(b)) * radius)


func _add_line(from: Vector3, to: Vector3) -> void:
	_immediate.surface_add_vertex(from)
	_immediate.surface_add_vertex(to)
	_vertex_count += 2
