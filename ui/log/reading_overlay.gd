class_name ReadingOverlay
extends CanvasLayer
## Reading panel (child of the Player): opens on the player's PersonalLog.entry_read (a datapad
## read in place, ADR 0060) with the entry's title and text; Esc or E closes it. The world keeps
## running (ADR 0110): while it is open it holds the player's OverlayFocus (input off, mouse free),
## like the computer screen; it closes when the player can no longer act (dead, knocked out).

var player: Player

@onready var title_label: Label = %Title
@onready var text_label: Label = %Text


func _ready() -> void:
	visible = false
	player = Entities.of_component(self) as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	var reader_log := PersonalLog.of(player)
	if reader_log != null:
		reader_log.entry_read.connect(read)


func _exit_tree() -> void:
	close()


func is_open() -> bool:
	return visible


## Shows a log entry's title and text.
func read(entry: LogEntry) -> void:
	open(entry.title, entry.text)


func open(title: String, text: String) -> void:
	title_label.text = title
	text_label.text = text if not text.is_empty() else "(blank)"
	if visible:
		return
	visible = true
	OverlayFocus.acquire(self, player)


func close() -> void:
	if not visible:
		return
	visible = false
	OverlayFocus.release(self)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(player) and not ActorState.can_act(player):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"use")):
		close()
		get_viewport().set_input_as_handled()
