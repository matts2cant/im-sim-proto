class_name ReadingOverlay
extends CanvasLayer
## Datapad reading panel (child of the Player): opens on PlayerInventory.read_requested with the
## stack's `title` and `text`, pauses the game (PauseScreens, ADR 0052); Esc or E closes it. Drawn
## above the inventory screen, which stays open underneath when the datapad was read from there.

var player: Player

@onready var title_label: Label = %Title
@onready var text_label: Label = %Text


func _ready() -> void:
	visible = false
	add_to_group(PauseScreens.GROUP)
	player = get_parent() as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	player.inventory.read_requested.connect(read)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


## Shows a datapad stack's text.
func read(stack: ItemStack) -> void:
	open(str(stack.state.get("title", stack.item.display_name)), str(stack.state.get("text", "")))


func open(title: String, text: String) -> void:
	title_label.text = title
	text_label.text = text if not text.is_empty() else "(blank)"
	visible = true
	PauseScreens.update(get_tree())


func close() -> void:
	if not visible:
		return
	visible = false
	PauseScreens.update(get_tree())
	if player != null:
		player.resync_actions()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"use")):
		close()
		get_viewport().set_input_as_handled()
