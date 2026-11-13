class_name Hitboxes
extends Node3D
## Six body-part hitboxes of a humanoid (origin at the feet, facing -Z), one AnimatableBody3D each on
## collision layer 5 (hitboxes) with no mask, tagged with metadata `body_part` (ADR 0047). Weapon
## rays and melee sweeps hit these instead of the character's body; StimulusSystem delivers to the
## entity's receivers with the hitbox as `collider`, and BodyParts reads the part from it. In group
## Entities.PARTS_GROUP: a hitbox stands for the character (Entities.of_collider()).

const META: StringName = &"body_part"

# Standing local heights of each hitbox, to squash them when crouching.
var _base_heights: Dictionary[Node3D, float] = {}


func _init() -> void:
	add_to_group(Entities.PARTS_GROUP)


func _ready() -> void:
	for box in boxes():
		_base_heights[box] = box.position.y


static func of(entity: Node) -> Hitboxes:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is Hitboxes:
			return child as Hitboxes
	return null


## The body part a collider stands for, or "" when it is not a hitbox.
static func part_of(node: Node) -> StringName:
	if node == null or not node.has_meta(META):
		return &""
	return StringName(str(node.get_meta(META)))


## RIDs of every hitbox under `entity` (a shooter excludes its own).
static func rids_of(entity: Node) -> Array[RID]:
	var result: Array[RID] = []
	var hitboxes := of(entity)
	if hitboxes != null:
		for box in hitboxes.boxes():
			result.append(box.get_rid())
	return result


func boxes() -> Array[CollisionObject3D]:
	var result: Array[CollisionObject3D] = []
	for child in get_children():
		if child is CollisionObject3D and child.has_meta(META):
			result.append(child as CollisionObject3D)
	return result


## The hitbox of `part`, or null.
func box(part: StringName) -> CollisionObject3D:
	for candidate in boxes():
		if part_of(candidate) == part:
			return candidate
	return null


## Moves the boxes down to `factor` of their standing heights (a crouched player is 0.95 / 1.8).
func set_height_factor(factor: float) -> void:
	for node: Node3D in _base_heights:
		node.position.y = _base_heights[node] * factor
