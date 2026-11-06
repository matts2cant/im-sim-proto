class_name AwarenessToggles
extends VBoxContainer
## Overlays tab section (self-contained): toggles the awareness feedback of every character
## (AwarenessIndicator): the `?` / `!` icons (on by default) and the state + meter text. Raises the
## level alarm (an `alarm.raise` stimulus from the player's position, ADR 0072) or clears it.

@onready var icons: CheckBox = $Icons
@onready var state_text: CheckBox = $StateText
@onready var raise_alarm: Button = $Alarm/Raise
@onready var clear_alarm: Button = $Alarm/Clear
@onready var alarm_state: Label = $Alarm/State


func _ready() -> void:
	icons.set_pressed_no_signal(AwarenessIndicator.show_icons)
	state_text.set_pressed_no_signal(AwarenessIndicator.show_state)
	icons.toggled.connect(_on_icons_toggled)
	state_text.toggled.connect(_on_state_text_toggled)
	raise_alarm.pressed.connect(raise_level_alarm)
	clear_alarm.pressed.connect(clear_level_alarm)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var alarm := LevelAlarm.current(get_tree())
	if alarm == null:
		alarm_state.text = "no alarm in level"
	elif alarm.is_raised():
		alarm_state.text = "ALARM %ds" % ceili(alarm.time_left())
	else:
		alarm_state.text = "off"


## Emits `alarm.raise` from the player (or the origin without one).
func raise_level_alarm() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var origin := player.global_position if player != null else Vector3.ZERO
	StimulusSystem.emit(LevelAlarm.make_raise(origin, player))


func clear_level_alarm() -> void:
	var alarm := LevelAlarm.current(get_tree())
	if alarm != null:
		alarm.clear()


func _on_icons_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_icons = pressed


func _on_state_text_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_state = pressed
