class_name BriefingScreen
extends CanvasLayer
## The mission briefing (ADR 0087): the mission's title, its text and the objective list, shown when
## a mission starts. A pause screen (PauseScreens: the game pauses and the mouse is free); E, Enter
## or Esc closes it and play starts. Built in code (MissionStyle).

signal closed

const HINT := "E / Enter / Esc: start"

## Told to take the keys still held as already held when it closes (Player.resync_actions()).
var player: Player

var _title: Label
var _text: Label
var _objectives: Label


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(PauseScreens.GROUP)
	var box := MissionStyle.centred_panel(self, 560.0)
	_title = MissionStyle.label("", 24, MissionStyle.TITLE)
	_title.name = "Title"
	box.add_child(_title)
	box.add_child(HSeparator.new())
	_text = MissionStyle.label("", 17, MissionStyle.TEXT)
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(504, 0)
	box.add_child(_text)
	_objectives = MissionStyle.label("", 17, MissionStyle.GOOD)
	_objectives.name = "Objectives"
	box.add_child(_objectives)
	var hint := MissionStyle.label(HINT, 13, MissionStyle.HINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


func title_text() -> String:
	return _title.text


func objectives_text() -> String:
	return _objectives.text


func open(title: String, text: String, objective_lines: PackedStringArray) -> void:
	_title.text = title
	_text.text = text
	_text.visible = not text.is_empty()
	_objectives.text = "\n".join(objective_lines)
	visible = true
	PauseScreens.update(get_tree())


func close() -> void:
	if not visible:
		return
	visible = false
	PauseScreens.update(get_tree())
	if is_instance_valid(player):
		player.resync_actions()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"use") or _is_enter(event):
		close()
		get_viewport().set_input_as_handled()


static func _is_enter(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	return key.keycode in [KEY_ENTER, KEY_KP_ENTER] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
