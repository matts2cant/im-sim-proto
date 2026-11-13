class_name AwarenessToggles
extends VBoxContainer
## Overlays tab section (self-contained): toggles the awareness feedback of every character
## (AwarenessIndicator): the `?` / `!` icons (on by default) and the state + meter text. "Raise
## alarm" / "Clear alarm" send `command.trigger` / `command.reset` to every alarm controller in the
## level (group `alarm_controller`, ADR 0077), straight from the panel: no network reach needed.

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
	alarm_state.text = state_text_for(AlarmController.all(get_tree()))


## The panel's alarm line for `controllers`: none, off, or the longest time left of the ringing ones.
static func state_text_for(controllers: Array[AlarmController]) -> String:
	if controllers.is_empty():
		return "no alarm controller in level"
	var left := 0.0
	for controller in controllers:
		left = maxf(left, controller.time_left())
	return "ALARM %ds" % ceili(left) if left > 0.0 else "off"


## Sends `command.trigger` to every alarm controller; returns how many.
func raise_level_alarm() -> int:
	return _command_all(AlarmController.TRIGGER)


## Sends `command.reset` to every alarm controller; returns how many.
func clear_level_alarm() -> int:
	return _command_all(AlarmController.RESET)


func _command_all(command: StringName) -> int:
	var player := get_tree().get_first_node_in_group(&"player")
	var controllers := AlarmController.all(get_tree())
	for controller in controllers:
		StimulusSystem.emit(Device.command_stimulus(command, controller.entity, player))
	return controllers.size()


func _on_icons_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_icons = pressed


func _on_state_text_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_state = pressed
