class_name UserScreen
extends CanvasLayer
## Base of a screen its user's Screens component opens on request (ADR 0133): the keypad, the
## lockpicking minigame, the computer overlay, the deck and the tuning panel. A screen is a child of
## its user (or instanced there by Screens on first use) and answers to one id (screen_id(): the
## constant of the thing that asks for it, KeypadLock.SCREEN, Computer.SCREEN...). World objects and
## items never name a screen class: they call Screens.open(user, id, subject, options). Each screen
## keeps its own pause and leave rules.


## The id world objects ask for (the requester's SCREEN constant).
func screen_id() -> StringName:
	return &""


func is_open() -> bool:
	return visible


## Opens on `subject` (the lock, computer, deck session or desk asking) for `user`; `options` are the
## screen's own (documented on it). False when it did not open.
func open_screen(_subject: Object, _user: Node, _options: Dictionary) -> bool:
	return false


## Closes it the way its own close does.
func close_screen() -> void:
	pass


## True while it is open on `subject`.
func shows(_subject: Object) -> bool:
	return false
