class_name ComputerApp
extends HBoxContainer
## Base of a Halcyon OS app (ADR 0114, 0133). ComputerScreen keeps its apps in a registry keyed by
## app id (the ids Computer.apps() lists): a new app is one more ComputerApp registered there, with
## its dock name; the screen calls these hooks and never names an app.


## Shows `computer`'s content for `viewer`, logged in as `account`.
func open_app(_computer: Computer, _viewer: Node, _account: String) -> void:
	pass


## On or off screen (an app rendering something live stops while hidden).
func set_shown(on: bool) -> void:
	visible = on


## Every refresh interval of the computer's config while it is the app shown.
func refresh_app() -> void:
	pass


## Every frame while the screen is open (also while hidden: to stop what runs).
func process_app() -> void:
	pass


## Inside a remote desktop (the deck's narrower panel) or not.
func set_compact(_compact: bool) -> void:
	pass
