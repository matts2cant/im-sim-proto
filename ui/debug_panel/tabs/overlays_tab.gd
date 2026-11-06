class_name OverlaysTab
extends VBoxContainer
## Debug panel tab: toggles world overlays. Stimuli: StimulusOverlay spheres and paths.

var stimulus_overlay: StimulusOverlay

@onready var _stimuli: CheckBox = $Stimuli


func _ready() -> void:
	_stimuli.toggled.connect(_on_stimuli_toggled)
	if stimulus_overlay != null:
		_stimuli.set_pressed_no_signal(stimulus_overlay.enabled)


func _on_stimuli_toggled(pressed: bool) -> void:
	if stimulus_overlay != null:
		stimulus_overlay.enabled = pressed
