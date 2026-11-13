class_name Eyes
extends Node
## Component of any character (ADR 0139): where it looks from and where it looks (-Z). The
## components that act on what a character looks at (Interactor, Carrier, the drop point of a
## PlayerInventory) ask it, never a concrete character class. `view_path` names the node whose global
## transform is the view (the player's camera, which eases after a step); without one, the view is
## `height` m above the entity's origin (its feet) facing the entity's -Z.

## Eye height above the origin when there is no view node (m).
const DEFAULT_HEIGHT: float = 1.6

## The node whose global transform is the view (the player's camera); empty: the entity's own.
@export var view_path: NodePath
## Eye height above the entity's origin when `view_path` is empty (m).
@export var height: float = DEFAULT_HEIGHT
@export var entity_path: NodePath = ^".."

var _view: Node3D
var _entity: Node3D


func _ready() -> void:
	_entity = Entities.of_component(self, entity_path) as Node3D
	if not view_path.is_empty():
		_view = get_node_or_null(view_path) as Node3D


static func of(node: Node) -> Eyes:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Eyes:
			return child as Eyes
	return null


## The view of `entity`: its Eyes', else `DEFAULT_HEIGHT` above its origin facing its -Z (identity
## when it is not a Node3D).
static func view_of(entity: Node) -> Transform3D:
	var eyes := of(entity)
	if eyes != null:
		return eyes.view()
	var body := entity as Node3D
	if body == null:
		return Transform3D.IDENTITY
	return _raised(body.global_transform, DEFAULT_HEIGHT)


## The view now: origin at the eyes, looking along -Z.
func view() -> Transform3D:
	if is_instance_valid(_view):
		return _view.global_transform
	if _entity == null:
		return Transform3D.IDENTITY
	return _raised(_entity.global_transform, height)


static func _raised(transform: Transform3D, up: float) -> Transform3D:
	return Transform3D(transform.basis, transform.origin + Vector3.UP * up)
