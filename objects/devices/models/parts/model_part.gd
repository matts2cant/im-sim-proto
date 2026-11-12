@tool
class_name ModelPart
extends Node3D
## Base of a device model's shared parts (ADR 0130 step 0): builds its meshes and labels as children
## without an owner (never saved with the scene, rebuilt on load), in _ready and whenever one of its
## exports changes (rebuild()). Subclasses implement _build() with _mesh() and _text().

## The nodes this part built (freed on rebuild).
var _built: Array[Node] = []


func _ready() -> void:
	rebuild()


## Builds the part again from its exports (nothing while out of the tree).
func rebuild() -> void:
	if not is_inside_tree():
		return
	for node in _built:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_built.clear()
	_build()


## Virtual: adds the part's nodes.
func _build() -> void:
	pass


## The kind of the model this part belongs to, or null.
func _kind() -> SecurityKind:
	return DeviceModel.kind_of(self)


## The kind's colour (grey without a kind).
func _kind_color() -> Color:
	var kind := _kind()
	return kind.color if kind != null else Color(0.5, 0.5, 0.5)


## Adds a mesh child named `node_name` at `at`.
func _mesh(node_name: String, mesh: Mesh, at: Vector3, material: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	instance.position = at
	_keep(instance)
	return instance


## Adds a ModelText child named `node_name`.
func _text(node_name: String, text: String, height: float, color: Color, at: Transform3D) -> ModelText:
	var label := ModelText.new()
	label.name = node_name
	label.text = text
	label.text_height = height
	label.modulate = color
	label.transform = at
	_keep(label)
	return label


func _keep(node: Node) -> void:
	add_child(node)
	_built.append(node)
