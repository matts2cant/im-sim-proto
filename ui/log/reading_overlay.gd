class_name ReadingOverlay
extends CanvasLayer
## Reading panel (child of the Player): opens on the player's PersonalLog.entry_read (a datapad
## read in place, ADR 0060) with the entry's title and text, pauses the game (PauseScreens,
## ADR 0052); Esc or E closes it.

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
	var reader_log := PersonalLog.of(player)
	if reader_log != null:
		reader_log.entry_read.connect(read)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


## Shows a log entry's title and text.
func read(entry: LogEntry) -> void:
	open(entry.title, entry.text)


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
