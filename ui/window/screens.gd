class_name Screens
extends Node
## The screens a user can be shown, found by id (ADR 0133). World objects and items ask for one
## (Screens.open(user, KeypadLock.SCREEN, lock)) instead of instancing or naming a concrete UI class;
## a user without that screen has none, and the caller does what it does for such a user.
## A screen is a UserScreen child of the user answering to the id (screen_id()). This component
## (optional, on the user) adds screens made on demand: the scene registered for an id in `scenes`
## is instanced as the user's child the first time it is asked for (the tuning panel).

## Screen id -> the UserScreen scene instanced as the user's child when it is first asked for.
@export var scenes: Dictionary[StringName, PackedScene] = {}


## The Screens child of `user`, or null.
static func of(user: Node) -> Screens:
	if user == null or not is_instance_valid(user):
		return null
	for child in user.get_children():
		if child is Screens:
			return child as Screens
	return null


## Opens `user`'s screen `id` on `subject` (its options: see the screen). False when the user has no
## such screen or it did not open.
static func open(user: Node, id: StringName, subject: Object, options: Dictionary = {}) -> bool:
	var found := screen_of(user, id)
	return found != null and found.open_screen(subject, user, options)


## True when `user` has screen `id` (or can make it).
static func has(user: Node, id: StringName) -> bool:
	if find(user, id) != null:
		return true
	var screens := of(user)
	return screens != null and screens.scenes.has(id)


## True while `user`'s screen `id` is open (on `subject`, when given).
static func is_open(user: Node, id: StringName, subject: Object = null) -> bool:
	var found := find(user, id)
	if found == null:
		return false
	return found.shows(subject) if subject != null else found.is_open()


## Closes `user`'s screen `id` if it is open (on `subject`, when given).
static func close(user: Node, id: StringName, subject: Object = null) -> void:
	if is_open(user, id, subject):
		find(user, id).close_screen()


## `user`'s screen `id`, instanced from its Screens' `scenes` when it has none yet; null when none.
static func screen_of(user: Node, id: StringName) -> UserScreen:
	var found := find(user, id)
	if found != null:
		return found
	var screens := of(user)
	return screens.make(id) if screens != null else null


## The screen `id` among `user`'s children (null: none, or not made yet).
static func find(user: Node, id: StringName) -> UserScreen:
	if user == null or not is_instance_valid(user):
		return null
	for child in user.get_children():
		var screen := child as UserScreen
		if screen != null and screen.screen_id() == id:
			return screen
	return null


## Instances the scene registered for `id` as the user's child; null when none is registered.
func make(id: StringName) -> UserScreen:
	var user := get_parent()
	if user == null or not scenes.has(id):
		return null
	var found := scenes[id].instantiate() as UserScreen
	if found == null:
		push_warning("Screens: the scene for %s is not a UserScreen" % id)
		return null
	user.add_child(found)
	return found
