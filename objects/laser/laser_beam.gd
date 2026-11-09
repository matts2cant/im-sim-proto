class_name LaserBeam
extends Node3D
## One beam of a laser array (ADR 0100), authored as a child of the array's entity: it runs from
## this node's origin (its emitter head's wall face, at the beam's height) along its local +Z for
## `length` metres, to the receiver's wall face. Each beam has its own height and length; the
## LaserArray beside the entity's Device watches every beam, builds their collision boxes on the
## entity's body and shows or hides their look. The look nodes are optional (a beam built in code
## has none).

## Gap (m) from the emitter head's wall face (this node's origin) to the receiver's along +Z.
@export var length: float = 3.0
## MeshInstance3D drawing the beam (its mesh is made by the array); optional.
@export var ray_path: NodePath = ^"Ray"
## Node3D moved to the far end of the beam (the receiver's look); optional.
@export var receiver_path: NodePath = ^"Receiver"
## The emitter head's lens, hidden while the array is broken; optional.
@export var lens_path: NodePath = ^"Head/Lens"


## The point `inset` metres along the beam from its emitter face (world).
func start_point(inset: float) -> Vector3:
	return to_global(Vector3(0.0, 0.0, inset))


## The point `inset` metres short of its receiver face (world).
func end_point(inset: float) -> Vector3:
	return to_global(Vector3(0.0, 0.0, length - inset))


## Places the receiver and makes the ray's mesh (`inset` from both ends, `color`).
func build(inset: float, color: Color) -> void:
	var receiver := get_node_or_null(receiver_path) as Node3D
	if receiver != null:
		receiver.position = Vector3(0.0, 0.0, length)
	var ray := get_node_or_null(ray_path) as MeshInstance3D
	if ray == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.016, 0.016, maxf(length - inset * 2.0, 0.01))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	ray.mesh = mesh
	ray.position = Vector3(0.0, 0.0, length * 0.5)
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Shows or hides the ray (watching or not) and the lens (unbroken or broken).
func show_state(ray_on: bool, lens_on: bool) -> void:
	var ray := get_node_or_null(ray_path) as Node3D
	if ray != null:
		ray.visible = ray_on
	var lens := get_node_or_null(lens_path) as Node3D
	if lens != null:
		lens.visible = lens_on


## True while the ray shows.
func ray_visible() -> bool:
	var ray := get_node_or_null(ray_path) as Node3D
	return ray != null and ray.visible
