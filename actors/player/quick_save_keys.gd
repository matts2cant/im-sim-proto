class_name QuickSaveKeys
extends Node
## Player child: F5 (`quicksave`) and F9 (`quickload`) through QuickSave (ADR 0063), with HUD
## messages. Runs while the game is paused (PROCESS_MODE_ALWAYS), so F9 works from the pause screens
## and the death screen. F5 is refused (silently) while dead or while a pause screen is open; both
## keys are ignored while the player's input is disabled or a quickload is running.

const SAVED := "Quicksaved"
const LOADED := "Quickloaded"
const NO_SAVE := "No quicksave"
const MESSAGES: Dictionary[SaveFile.Status, String] = {
	SaveFile.Status.MISSING: NO_SAVE,
	SaveFile.Status.CORRUPT: "Quicksave is damaged",
	SaveFile.Status.WRONG_VERSION: "Quicksave is from another version",
	SaveFile.Status.UNWRITABLE: "Could not write the quicksave",
	SaveFile.Status.NO_LEVEL: "Quicksave level not found",
}

var player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(QuickSave.LOADED_GROUP)
	player = get_parent() as Player


func _unhandled_input(event: InputEvent) -> void:
	# Handled first: a quickload takes this node out of the tree at once.
	if event.is_action_pressed(&"quicksave"):
		get_viewport().set_input_as_handled()
		quicksave()
	elif event.is_action_pressed(&"quickload"):
		get_viewport().set_input_as_handled()
		quickload()


func can_quicksave() -> bool:
	return _keys_enabled() and not player.is_dead() and not PauseScreens.any_open(get_tree())


## F5: saves now; false when refused or the write failed.
func quicksave() -> bool:
	if not can_quicksave():
		return false
	var status := QuickSave.save_game(get_tree())
	_show(SAVED if status == SaveFile.Status.OK else MESSAGES.get(status, NO_SAVE))
	return status == SaveFile.Status.OK


## F9: starts loading the quicksave (this node is freed with the level on the way; the new player's
## QuickSaveKeys shows "Quickloaded"). False, with a message, when there is nothing to load.
func quickload() -> bool:
	if not _keys_enabled():
		return false
	var status := QuickSave.check()
	if status != SaveFile.Status.OK:
		_show(MESSAGES.get(status, NO_SAVE))
		return false
	QuickSave.load_game(get_tree())
	return true


## QuickSave.LOADED_GROUP: the load this player came from has finished.
func on_quickloaded() -> void:
	_show(LOADED)


func _keys_enabled() -> bool:
	return player != null and player.input_enabled and not QuickSave.is_loading()


func _show(text: String) -> void:
	var hud := player.get_node_or_null(^"Hud") as Hud if player != null else null
	if hud != null:
		hud.show_message(text)
