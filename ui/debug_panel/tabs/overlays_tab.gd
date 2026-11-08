class_name OverlaysTab
extends VBoxContainer
## Debug panel tab: toggles world overlays. Stimuli: StimulusOverlay spheres and paths.
## Heat: HeatOverlay labels (heat / threshold, fuel left) above flammables and explosives.
## Network: NetworkOverlay labels (name, status) above devices and their cables (ADR 0083).

var stimulus_overlay: StimulusOverlay
var heat_overlay: HeatOverlay
var network_overlay: NetworkOverlay

@onready var _stimuli: CheckBox = $Stimuli
@onready var _heat: CheckBox = $Heat
@onready var _network: CheckBox = $Network


func _ready() -> void:
	_stimuli.toggled.connect(_on_stimuli_toggled)
	_heat.toggled.connect(_on_heat_toggled)
	_network.toggled.connect(_on_network_toggled)
	if stimulus_overlay != null:
		_stimuli.set_pressed_no_signal(stimulus_overlay.enabled)
	if heat_overlay != null:
		_heat.set_pressed_no_signal(heat_overlay.enabled)
	if network_overlay != null:
		_network.set_pressed_no_signal(network_overlay.enabled)


func _on_stimuli_toggled(pressed: bool) -> void:
	if stimulus_overlay != null:
		stimulus_overlay.enabled = pressed


func _on_heat_toggled(pressed: bool) -> void:
	if heat_overlay != null:
		heat_overlay.enabled = pressed


func _on_network_toggled(pressed: bool) -> void:
	if network_overlay != null:
		network_overlay.enabled = pressed
