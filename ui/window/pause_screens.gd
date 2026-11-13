class_name PauseScreens
extends RefCounted
## Full-screen UI that pauses the game (ADR 0052): only the game menu (ADR 0064), the mission
## briefing, the end-of-mission summary (ADR 0087) and the loot screen (ADR 0142, which also holds its
## user's OverlayFocus to hide the HUD). Every other screen (the Tab interface, the
## keypad, the reading overlay, the computer screen, the lockpicking screen) keeps the world running and
## holds its user's OverlayFocus instead (ADR 0110, 0133).
## Each such CanvasLayer joins GROUP, runs with PROCESS_MODE_ALWAYS, has is_open(), and calls
## update() after opening or closing. While any is open the SceneTree is paused and the mouse is
## free (an OverlayFocus hold of the tree, for no user); when the last one closes the pause ends and
## the hold goes (the mouse back to its mode from before, or to the open overlay's).

const GROUP: StringName = &"pause_screen"

static var _pausing: bool = false


static func any_open(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		if node.call(&"is_open"):
			return true
	return false


static func update(tree: SceneTree) -> void:
	var open := any_open(tree)
	if open and not _pausing:
		_pausing = true
		tree.paused = true
		OverlayFocus.acquire_all(tree)
	elif not open and _pausing:
		_pausing = false
		tree.paused = false
		OverlayFocus.release(tree)


## Tests: forget a pause left by a freed screen.
static func reset(tree: SceneTree) -> void:
	if _pausing:
		tree.paused = false
	_pausing = false
	OverlayFocus.release(tree)
