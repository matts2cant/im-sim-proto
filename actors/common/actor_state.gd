class_name ActorState
extends RefCounted
## A character's state read from its tags (the entity's `Tags` child), so whatever adds a tag has
## the same effect: BodyParts writes `state.dead`, `state.unconscious`, `state.arms_disabled` and
## `state.legs_disabled` from its injuries, and an Effect can add the same tags (sleep gas
## `state.unconscious`, handcuffs `state.arms_disabled`). Movement controllers write the stance tags
## that MovementNoise reads (ADR 0056). An entity without Tags has none of them.

const DEAD: StringName = &"state.dead"
const UNCONSCIOUS: StringName = &"state.unconscious"
## Both arms disabled (or bound): cannot use weapons.
const ARMS_DISABLED: StringName = &"state.arms_disabled"
## Both legs disabled (or bound): forced crawl.
const LEGS_DISABLED: StringName = &"state.legs_disabled"
## Stance tags, set by the character's movement controller.
const CROUCHING: StringName = &"stance.crouch"
const SPRINTING: StringName = &"stance.sprint"
## Set by a controller while it moves the body by script instead of move_and_slide() (a mantle):
## StepClimber leaves the body alone.
const MANTLING: StringName = &"stance.mantle"
## Added by the Cloak augmentation (any source may add it): guards' sight ignores the entity (M7;
## cameras and turrets still see it).
const CLOAKED: StringName = &"state.cloaked"


static func tags_of(entity: Node) -> Tags:
	if entity == null:
		return null
	return entity.get_node_or_null(^"Tags") as Tags


static func has(entity: Node, tag: StringName) -> bool:
	var tags := tags_of(entity)
	return tags != null and tags.has(tag)


## Adds or removes `tag` (no-op without Tags).
static func set_tag(entity: Node, tag: StringName, on: bool) -> void:
	var tags := tags_of(entity)
	if tags == null:
		return
	if on:
		tags.add(tag)
	else:
		tags.remove(tag)


static func is_dead(entity: Node) -> bool:
	return has(entity, DEAD)


## Alive and conscious: may move, use things and fire.
static func can_act(entity: Node) -> bool:
	return not has(entity, DEAD) and not has(entity, UNCONSCIOUS)


## Can act and has the use of its arms (weapons).
static func can_use_arms(entity: Node) -> bool:
	return can_act(entity) and not has(entity, ARMS_DISABLED)


static func legs_disabled(entity: Node) -> bool:
	return has(entity, LEGS_DISABLED)
