class_name ActorState
extends RefCounted
## A character's state read from its tags (Tags.of(entity)), so whatever adds a tag has
## the same effect: BodyParts writes `state.dead`, `state.unconscious`, `state.arms_disabled` and
## `state.legs_disabled` from its injuries, and an Effect can add the same tags (sleep gas
## `state.unconscious`, handcuffs `state.arms_disabled`). Movement controllers write the stance tags
## that MovementNoise reads (ADR 0056). An entity without Tags has none of them.

## The player character's kind tag: the one definition (game systems find and attribute to the
## player by it, never by name, group or class; ADR 0136, ADR 0139).
const PLAYER: StringName = &"actor.player"
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
## On any entity (a character, a device, a radio) while a jamming field covers it (JammingField adds
## and removes it, ADR 0138): its wireless links carry nothing (DeviceNetwork.is_jammed(), the deck's
## Wi-Fi, radio messages to or from it).
const JAMMED: StringName = &"state.jammed"


static func has(entity: Node, tag: StringName) -> bool:
	var tags := Tags.of(entity)
	return tags != null and tags.has(tag)


## Adds or removes `tag` (no-op without Tags).
static func set_tag(entity: Node, tag: StringName, on: bool) -> void:
	var tags := Tags.of(entity)
	if tags == null:
		return
	if on:
		tags.add(tag)
	else:
		tags.remove(tag)


## True while a jamming field covers `entity` (JAMMED); false for a freed or missing entity.
static func is_jammed(entity: Node) -> bool:
	return entity != null and is_instance_valid(entity) and has(entity, JAMMED)


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
