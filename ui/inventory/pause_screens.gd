class_name PauseScreens
extends RefCounted
## Full-screen UI that pauses the game (ADR 0052): the inventory screen, the reading overlay and the
## log screen (ADR 0060).
## Each such CanvasLayer joins GROUP, runs with PROCESS_MODE_ALWAYS, has is_open(), and calls
## update() after opening or closing. While any is open the SceneTree is paused and the mouse is
## free; when the last one closes the pause ends and the previous mouse mode comes back.

const GROUP: StringName = &"pause_screen"

static var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
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
		_mouse_before = Input.mouse_mode
		tree.paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not open and _pausing:
		_pausing = false
		tree.paused = false
		Input.mouse_mode = _mouse_before


## Tests: forget a pause left by a freed screen.
static func reset(tree: SceneTree) -> void:
	if _pausing:
		tree.paused = false
	_pausing = false
