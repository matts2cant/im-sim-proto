class_name Lootable
extends Usable
## Component (ADR 0142): its entity's Inventory (and Keychain, if it has one) can be looted. E (a
## tap, through the Interactor) opens the user's loot screen on the entity
## (Screens.open(user, SCREEN, entity)); the screen moves items and keys with Inventory.of() and
## Keychain.of() of both sides. Decided by properties only:
## - a character (BodyParts makes one) is lootable only while down (ActorState.can_act() false:
##   dead or unconscious); anything else (a container) at any time;
## - while its Lockable is locked it is not lootable: E tries its locks (Lock.use_locked(): a key on
##   the user's Keychain unlocks a MechanicalLock, a card grants a KeycardLock's opening) and opens
##   the screen when one lets the user in; a lockpick works it like any lock (ToolUse). The frame's
##   lock line and E's "Locked: needs ..." come from the Lockable like a door's;
## - the user needs an Inventory, and for E a loot screen (Screens.has(user, SCREEN)): without one
##   the Interactor does what it did before (a downed body is carried at once). Any character can
##   loot through can_loot() and the Inventory API; the screen is the player's UI.
## Holding E carries a downed body that is also Carryable (the Interactor's hold action).
## EventLog `loot.opened {entity, by}`.

## The screen id the loot screen answers to (a UserScreen of the user).
const SCREEN: StringName = &"loot"

@export var entity_path: NodePath = ^".."

var entity: Node


func _init() -> void:
	verb = "search"


func _ready() -> void:
	entity = Entities.of_component(self, entity_path)


static func of(node: Node) -> Lootable:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Lootable:
			return child as Lootable
	return null


## True when `user` may loot it now: it has an Inventory, the user has one (and is not it), a
## character is down, and it is not locked.
func can_loot(user: Node) -> bool:
	return _open_to(user) and not _locked()


## The Interactor offers it to `user` (E opens the screen or tries its locks): the user has the
## loot screen and could loot it once unlocked.
func available(user: Node) -> bool:
	return _open_to(user) and Screens.has(user, SCREEN)


func lock_target() -> Lockable:
	return Lockable.of(entity)


## While locked: a lock's progress ("Picking 40%") or offer ("E: open (keycard)"), else "Locked:
## <what opens it>"; unlocked: the default "E: search <name>".
func prompt(user: Node) -> String:
	if not _locked():
		return ""
	var locks := Lock.locks_of(entity)
	for each in locks:
		var progress := each.tool_progress()
		if progress >= 0.0:
			return "Picking %d%%" % roundi(progress * 100.0)
	for each in locks:
		var text := each.use_prompt(user)
		if not text.is_empty():
			return text
	var words := LockRules.opening_words(lock_target().reasons(user))
	return "Locked" if words.is_empty() else "Locked: %s" % " or ".join(words)


## E: opens `user`'s loot screen on the entity; while locked, first lets a lock let the user in (a
## key unlocks, a card grants one opening). False when nothing opened.
func use(user: Node) -> bool:
	if not _open_to(user):
		return false
	if _locked() and not _try_locks(user):
		return false
	if not Screens.open(user, SCREEN, entity):
		return false
	var who := EntityNames.log_name(user)
	var target := EntityNames.log_name(entity)
	EventLog.record(EventKinds.LOOT_OPENED, who, target, {"entity": target, "by": who})
	used.emit(user)
	return true


# Its side and the user's allow looting, locks aside.
func _open_to(user: Node) -> bool:
	if entity == null or user == null or user == entity or not is_instance_valid(user):
		return false
	if Inventory.of(entity) == null or Inventory.of(user) == null:
		return false
	return BodyParts.of(entity) == null or not ActorState.can_act(entity)


func _locked() -> bool:
	var lockable := lock_target()
	return lockable != null and lockable.locked


func _try_locks(user: Node) -> bool:
	for each in Lock.locks_of(entity):
		if each.use_locked(user):
			return true
	return false
