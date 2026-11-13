class_name Screens
extends Node
## Component of a user (the Player; ADR 0133): the screens it can be shown, found by id. World
## objects and items ask it to open a screen (Screens.open(user, KeypadLock.SCREEN, lock)) instead of
## instancing or naming a concrete UI class; a user without the component (or without that screen)
## has no screen, and the caller does what it does for such a user.
## A screen is a UserScreen child of the user answering to the id (screen_id()), or the scene
## registered for the id in `scenes`, instanced as the user's child on first use (the tuning panel).

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
	var screens := of(user)
	return screens != null and (screens.find(id) != null or screens.scenes.has(id))


## True while `user`'s screen `id` is open (on `subject`, when given).
static func is_open(user: Node, id: StringName, subject: Object = null) -> bool:
	var screens := of(user)
	var found := screens.find(id) if screens != null else null
	if found == null:
		return false
	return found.shows(subject) if subject != null else found.is_open()


## Closes `user`'s screen `id` if it is open (on `subject`, when given).
static func close(user: Node, id: StringName, subject: Object = null) -> void:
	if is_open(user, id, subject):
		of(user).find(id).close_screen()


## `user`'s screen `id`, instanced from `scenes` when it has none yet; null when it has none.
static func screen_of(user: Node, id: StringName) -> UserScreen:
	var screens := of(user)
	return screens.get_screen(id) if screens != null else null


## The screen `id` among the user's children (null: none yet).
func find(id: StringName) -> UserScreen:
	var user := get_parent()
	if user == null:
		return null
	for child in user.get_children():
		var screen := child as UserScreen
		if screen != null and screen.screen_id() == id:
			return screen
	return null


## The screen `id`, instanced from `scenes` as the user's child when missing; null when it has none.
func get_screen(id: StringName) -> UserScreen:
	var found := find(id)
	if found != null or not scenes.has(id) or get_parent() == null:
		return found
	found = scenes[id].instantiate() as UserScreen
	if found == null:
		push_warning("Screens: the scene for %s is not a UserScreen" % id)
		return null
	get_parent().add_child(found)
	return found
