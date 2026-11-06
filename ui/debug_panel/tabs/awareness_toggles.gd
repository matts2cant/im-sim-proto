class_name AwarenessToggles
extends VBoxContainer
## Overlays tab section (self-contained): toggles the awareness feedback of every character
## (AwarenessIndicator): the `?` / `!` icons (on by default) and the state + meter text.

@onready var icons: CheckBox = $Icons
@onready var state_text: CheckBox = $StateText


func _ready() -> void:
	icons.set_pressed_no_signal(AwarenessIndicator.show_icons)
	state_text.set_pressed_no_signal(AwarenessIndicator.show_state)
	icons.toggled.connect(_on_icons_toggled)
	state_text.toggled.connect(_on_state_text_toggled)


func _on_icons_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_icons = pressed


func _on_state_text_toggled(pressed: bool) -> void:
	AwarenessIndicator.show_state = pressed
