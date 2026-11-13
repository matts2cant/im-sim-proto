extends UserScreen
## Test stand-in for a user's loot screen (ADR 0142): answers to Lootable.SCREEN and records what it
## was opened on, so tests of the E path need no UI. Add it as a child of the user.

var subject: Object = null
var opened_by: Node = null
var opened: int = 0


func _init() -> void:
	visible = false


func screen_id() -> StringName:
	return Lootable.SCREEN


func open_screen(p_subject: Object, p_user: Node, _options: Dictionary) -> bool:
	subject = p_subject
	opened_by = p_user
	opened += 1
	visible = true
	return true


func close_screen() -> void:
	visible = false


func shows(p_subject: Object) -> bool:
	return visible and p_subject == subject


## A stand-in added to `user` (named "LootScreen").
static func add_to(user: Node) -> UserScreen:
	var screen: UserScreen = load("res://tests/items/inventory/fixtures/loot_screen_stand_in.gd").new()
	screen.name = "LootScreen"
	user.add_child(screen)
	return screen
