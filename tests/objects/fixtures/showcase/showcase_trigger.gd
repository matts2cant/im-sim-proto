extends Node
## Showcase helper (screenshots only): after `delay` seconds sends one CONTACT stimulus to `target`,
## and optionally opens a debug panel tab.

@export var target: NodePath
@export var delay: float = 0.5
@export var type: StringName = &"fire"
@export var intensity: float = 100.0
## Debug panel tab to open at start ("" = leave the panel closed).
@export var open_tab: String = ""
## When set: after `capture_after` seconds, saves the window's image (UI included) here and quits.
## tools/screenshot.sh crops the 2D layer when the window is smaller than the base size.
@export var capture_path: String = ""
@export var capture_after: float = 1.0
## Turns on the debug Heat overlay.
@export var show_heat: bool = false

var _time: float = 0.0
var _done: bool = false


func _ready() -> void:
	DebugPanel.heat_overlay.enabled = show_heat
	if open_tab.is_empty():
		return
	DebugPanel.set_open(true)
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == open_tab:
			tabs.current_tab = i


func _process(_delta: float) -> void:
	if capture_path.is_empty() or _time < capture_after:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(capture_path))
	capture_path = ""
	get_tree().quit()


func _physics_process(delta: float) -> void:
	_time += delta
	if _done or _time < delay or target.is_empty():
		return
	_done = true
	var node := get_node_or_null(target)
	if node != null:
		StimulusSystem.emit(Stimulus.make_contact(type, intensity, node))
