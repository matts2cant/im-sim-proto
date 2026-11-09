@tool
class_name Fence
extends StaticBody3D
## A see-through barrier of vertical bars: a palisade fence or a catwalk railing. Bodies cannot pass
## the gaps between bars (narrower than a 0.7 m capsule); sight, shots and light rays mostly do,
## because they only stop where they hit a bar or a rail. Not CSG: one triangle-mesh collision shape
## and one MultiMesh, so a long fence stays cheap. On the world layer and in the
## `navigation_source` group, so LevelNavigation keeps guards off it.
## Origin: bottom of the first bar; the fence runs along +X for `length`, bars centred on z = 0.
## Thin tops cannot be mantled (the mantle needs a floor-like top 0.1 m past the face).

const NAVIGATION_GROUP: StringName = &"navigation_source"
const MATERIAL_PATH := "res://assets/materials/graybox/metal.tres"
## Openings at least this wide and this tall would let a crouched capsule (0.7 x 0.95 m) through.
const MAX_GAP := 0.6
const MAX_OPENING_HEIGHT := 0.9

@export_range(0.1, 200.0, 0.05, "or_greater", "suffix:m") var length := 4.0:
	set(value):
		length = value
		rebuild()
@export_range(0.1, 10.0, 0.05, "or_greater", "suffix:m") var height := 3.0:
	set(value):
		height = value
		rebuild()
## Centre-to-centre distance between bars (bars at both ends; spacing evened out).
@export_range(0.05, 5.0, 0.01, "suffix:m") var bar_spacing := 0.22:
	set(value):
		bar_spacing = value
		rebuild()
## Bar and rail section (square), in metres.
@export_range(0.01, 0.5, 0.01, "suffix:m") var bar_width := 0.05:
	set(value):
		bar_width = value
		rebuild()
## Heights of horizontal rails above the bottom (the rail's centre).
@export var rails: PackedFloat32Array = PackedFloat32Array([0.3, 2.7]):
	set(value):
		rails = value
		rebuild()

var _generated: Array[Node] = []
var _warnings: PackedStringArray = []


func _init() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	rebuild()


func _ready() -> void:
	add_to_group(NAVIGATION_GROUP)


## Bar centres along x.
func bar_positions() -> PackedFloat32Array:
	var l := maxf(length, 0.1)
	var count := maxi(2, ceili(l / maxf(bar_spacing, 0.05) - 0.0001) + 1)
	var result := PackedFloat32Array()
	for i in count:
		result.append(l * i / (count - 1))
	return result


## Regenerates the collision shape and the visual MultiMesh from the properties.
func rebuild() -> void:
	for node: Node in _generated:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_generated.clear()
	_warnings = PackedStringArray()
	var boxes := _boxes()
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var mesh_shape := ConcavePolygonShape3D.new()
	# Closed boxes: both windings collide, so the face order never matters.
	mesh_shape.backface_collision = true
	mesh_shape.set_faces(_faces(boxes))
	shape.shape = mesh_shape
	_add_generated(shape)
	var visual := MultiMeshInstance3D.new()
	visual.name = "Bars"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var unit := BoxMesh.new()
	unit.material = load(MATERIAL_PATH) as Material
	multimesh.mesh = unit
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		var box: AABB = boxes[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(box.size), box.get_center()))
	visual.multimesh = multimesh
	_add_generated(visual)
	var positions := bar_positions()
	if (
		positions.size() > 1
		and positions[1] - positions[0] - bar_width >= MAX_GAP
		and tallest_opening() >= MAX_OPENING_HEIGHT
	):
		_warn("Gaps of %.2f m between bars let a crouched player through." % (positions[1] - positions[0] - bar_width))
	update_configuration_warnings()


## Tallest clear span between the ground, the rails and the top (rails close the gaps between bars).
func tallest_opening() -> float:
	var w := clampf(bar_width, 0.01, 0.5)
	var h := maxf(height, 0.1)
	var edges: Array[float] = [0.0, h]
	for rail: float in rails:
		var y := clampf(rail, w * 0.5, h - w * 0.5)
		edges.append(y - w * 0.5)
		edges.append(y + w * 0.5)
	edges.sort()
	var tallest := 0.0
	for i in range(0, edges.size() - 1, 2):
		tallest = maxf(tallest, edges[i + 1] - edges[i])
	return tallest


func _get_configuration_warnings() -> PackedStringArray:
	return _warnings


func _warn(message: String) -> void:
	_warnings.append(message)


# Every bar and rail as a box in local space.
func _boxes() -> Array[AABB]:
	var w := clampf(bar_width, 0.01, 0.5)
	var h := maxf(height, 0.1)
	var l := maxf(length, 0.1)
	var result: Array[AABB] = []
	for x: float in bar_positions():
		result.append(AABB(Vector3(x - w * 0.5, 0.0, -w * 0.5), Vector3(w, h, w)))
	for rail: float in rails:
		var y := clampf(rail, w * 0.5, h - w * 0.5)
		result.append(AABB(Vector3(-w * 0.5, y - w * 0.5, -w * 0.5), Vector3(l + w, w, w)))
	return result


static func _faces(boxes: Array[AABB]) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for box: AABB in boxes:
		var a := box.position
		var b := box.end
		var c: Array[Vector3] = [
			Vector3(a.x, a.y, a.z),
			Vector3(b.x, a.y, a.z),
			Vector3(b.x, b.y, a.z),
			Vector3(a.x, b.y, a.z),
			Vector3(a.x, a.y, b.z),
			Vector3(b.x, a.y, b.z),
			Vector3(b.x, b.y, b.z),
			Vector3(a.x, b.y, b.z),
		]
		for quad: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2]]:
			faces.append_array([c[quad[0]], c[quad[1]], c[quad[2]], c[quad[0]], c[quad[2]], c[quad[3]]])
	return faces


func _add_generated(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_generated.append(node)
