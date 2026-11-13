class_name Usable
extends Node
## Component: something the player can `use` (E) while looking at it, before trying to pick it up.
## Subclasses override use(); the base only emits `used` (a training dummy resets on it). When E
## does nothing, the Interactor shows why: unavailable_reason() or refusal() (ADR 0130).

signal used(user: Node)

const BROKEN_REASON := "Broken"
const NO_POWER_REASON := "No power"

## What the HUD / log calls the action.
@export var verb: String = "use"


static func of(node: Node) -> Usable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Usable:
			return child as Usable
	return null


## What the prompt calls the target ("E: read Storage access"); empty: the entity's own name.
func target_name() -> String:
	return ""


## False when `user` cannot use it now (no prompt, E does nothing else either: a broken door).
func available(_user: Node) -> bool:
	return true


## Why E does nothing while it is not available (ADR 0130: the HUD's short message), "" to say
## nothing. Default: from its entity's state, whatever the entity is: "Broken" (`state.broken`, a
## depleted Breakable), "No power" (`state.unpowered`, a Powered that is off).
func unavailable_reason(_user: Node) -> String:
	return Usable.state_reason(get_parent())


## Why E on it did nothing after use() returned false (ADR 0130), "" to say nothing. Default: what
## opens it while its lock_target() is locked ("Locked: needs a keycard").
func refusal(user: Node) -> String:
	var target := lock_target()
	if target == null or not target.locked:
		return ""
	return LockRules.needs_message(target.reasons(user))


## The Lockable E works on: its entity's, or null. A component working another entity's lock
## overrides it (a door controller's wall box: its door's, ADR 0130); the frame's lock line and
## refusal() read it.
func lock_target() -> Lockable:
	return Lockable.of(get_parent())


## "Broken" or "No power" from `entity`'s components and state tags, else "".
static func state_reason(entity: Node) -> String:
	if entity == null or not is_instance_valid(entity):
		return ""
	var breakable := Breakable.of(entity)
	if ActorState.has(entity, Device.BROKEN) or (breakable != null and breakable.is_broken):
		return BROKEN_REASON
	var powered := Powered.of(entity)
	if ActorState.has(entity, Device.UNPOWERED) or (powered != null and not powered.is_on()):
		return NO_POWER_REASON
	return ""


## The whole prompt for `user` when it is not "E: <verb> <target>" ("Locked: keycard"); "" for the
## default.
func prompt(_user: Node) -> String:
	return ""


## Returns true when the use did something (the player then does not try to pick the object up).
func use(user: Node) -> bool:
	used.emit(user)
	return true
