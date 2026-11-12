class_name ModelStyle
extends RefCounted
## Shared look of the device models (ADR 0130 step 0): the materials in `parts/materials/`, the
## labels' font, the label colours, the kind colour materials (built once per colour from
## DeviceKinds) and a helper that merges boxes into one mesh. Parts and LinkingBay read it; nothing
## here names a device.

const FONT: Font = preload("res://objects/devices/models/parts/model_font.tres")
## The status light's look (StatusLight's shader): LEDs and port lights.
const STATUS_MATERIAL: Material = preload("res://objects/devices/status_light_material.tres")
const BODY: Material = preload("res://objects/devices/models/parts/materials/body.tres")
const FACE: Material = preload("res://objects/devices/models/parts/materials/face.tres")
const RAIL: Material = preload("res://objects/devices/models/parts/materials/rail.tres")
const SOCKET: Material = preload("res://objects/devices/models/parts/materials/socket.tres")
const PLATE: Material = preload("res://objects/devices/models/parts/materials/plate.tres")
const BLANK: Material = preload("res://objects/devices/models/parts/materials/blank.tres")
const RACK_FRAME: Material = preload("res://objects/devices/models/parts/materials/rack_frame.tres")
const GLASS: Material = preload("res://objects/devices/models/parts/materials/glass.tres")
const LOCK_METAL: Material = preload("res://objects/devices/models/parts/materials/lock_metal.tres")
const CABLE: Material = preload("res://objects/devices/models/parts/materials/cable.tres")

## Light text on a dark front (port labels), dark text on a light plate.
const LABEL_LIGHT := Color(0.851, 0.867, 0.878)
const PLATE_TEXT := Color(0.102, 0.114, 0.125)
## Status light colours (StatusLight): online, locked or disabled, dark.
const ONLINE := Color(0.15, 1.0, 0.3)
const RED := Color(1.0, 0.12, 0.08)
const DARK := Color(0.06, 0.07, 0.06)


## The material of a kind's strip and icon in `color` (one per part: no static cache, which would
## outlive the scene tree at exit).
static func kind_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "kind_" + color.to_html(false)
	material.albedo_color = color
	material.roughness = 0.45
	return material


## A box mesh of `size` with `material`.
static func box(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


## One mesh of axis-aligned `boxes` (no shared faces are removed), in `material`.
static func boxes_mesh(boxes: Array[AABB], material: Material) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for b in boxes:
		_add_box(b, vertices, normals, indices)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


# Six faces, each wound clockwise seen from outside (Godot's front faces): corners at -u+v, +u+v,
# +u-v, -u-v with u x v = the face normal.
static func _add_box(
	b: AABB, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array
) -> void:
	var centre := b.get_center()
	var half := b.size * 0.5
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = (face[1] as Vector3) * half
		var v: Vector3 = (face[2] as Vector3) * half
		var c := centre + n * half
		var start := vertices.size()
		for corner: Vector3 in [c - u + v, c + u + v, c + u - v, c - u - v]:
			vertices.append(corner)
			normals.append(n)
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
