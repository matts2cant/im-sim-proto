class_name Entities
extends RefCounted
## How entities and their components find each other (conventions.md "Entities and components").
## An entity is a node whose direct children are its components (Tags, Attributes, a
## StimulusReceiver, Breakable, ...). Pure static helpers, no game content:
## - of_component(): the entity a component works for (its `entity_path`, `..` by default);
## - of_collider(): the entity a physics collider stands for (a character's hitbox: the character);
## - members(): an entity's components that implement a component interface (group + method).

## The group of a node whose collider children are parts of the node's parent entity (a character's
## Hitboxes: a hit on a hitbox is a hit on the character).
const PARTS_GROUP: StringName = &"entity_parts"


## The entity of `component`: the node at `path` from it (a component's exported `entity_path`; its
## parent by default), or null when there is none.
static func of_component(component: Node, path: NodePath = ^"..") -> Node:
	if component == null or not is_instance_valid(component):
		return null
	return component.get_node_or_null(path)


## The entity `collider` stands for: when its parent is in PARTS_GROUP (a hitbox under a character's
## Hitboxes), that parent's parent; otherwise the collider itself. Null for null. Ray and shape
## queries resolve what they hit through this (the Interactor, the Carrier, lasers, shot feedback,
## the StimulusSystem's delivery).
static func of_collider(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null
	var parent := collider.get_parent()
	if parent != null and parent.is_in_group(PARTS_GROUP) and parent.get_parent() != null:
		return parent.get_parent()
	return collider


## The direct children of `entity` that implement a component interface: in group `group` and, when
## `method` is given, having it. In tree order; empty for a missing entity.
static func members(entity: Node, group: StringName, method: StringName = &"") -> Array[Node]:
	var found: Array[Node] = []
	if entity == null or not is_instance_valid(entity):
		return found
	for child in entity.get_children():
		if child.is_in_group(group) and (method.is_empty() or child.has_method(method)):
			found.append(child)
	return found
