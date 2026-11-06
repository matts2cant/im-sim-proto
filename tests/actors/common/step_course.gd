extends RefCounted
## Test helper (not a suite): step and stair geometry built in code for StepClimber tests (ADR 0058).
## Everything faces +Z towards a character that walks toward -Z: an obstacle's near face is at
## z = `face_z` and it runs `depth` metres further toward -Z. Static boxes on the world layer.

## Riser and tread of the test stair (the brief's 6 x 0.17 m, 0.3 m treads).
const RISE: float = 0.17
const TREAD: float = 0.3
const RISERS: int = 6
## Depth (m) of the landing at the top of the stair.
const LANDING: float = 3.0


## A static box from the floor (y = 0) to `top`, `width` wide (X) centred on `x`, its near face at
## `face_z`, `depth` deep toward -Z.
static func block(
	parent: Node, top: float, face_z: float, depth: float = 3.0, x: float = 0.0, width: float = 2.0
) -> StaticBody3D:
	return slab(parent, 0.0, top, face_z, depth, x, width)


## A static box between heights `bottom` and `top` (a ceiling when it floats), otherwise as block().
static func slab(
	parent: Node, bottom: float, top: float, face_z: float, depth: float, x: float = 0.0, width: float = 2.0
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, top - bottom, depth)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(x, (top + bottom) * 0.5, face_z - depth * 0.5)
	parent.add_child(body)
	return body


## The test stair: RISERS risers of RISE, treads of TREAD, the first riser's face at `face_z`, then a
## LANDING-deep landing at RISERS x RISE. Returns the landing's height.
static func stair(parent: Node, face_z: float, x: float = 0.0, width: float = 2.0) -> float:
	for i in RISERS:
		var depth := TREAD if i < RISERS - 1 else LANDING
		block(parent, RISE * (i + 1), face_z - TREAD * i, depth, x, width)
	return RISE * RISERS


## Near-face z of the landing at the top of a stair whose first face is at `face_z`.
static func landing_face(face_z: float) -> float:
	return face_z - TREAD * (RISERS - 1)
