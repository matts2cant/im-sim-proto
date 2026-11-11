extends Control
## Audition for the lockpicking sounds (ADR 0108): run this scene (F6 in the editor) to play every
## cue (buttons or keys 1-0) and sweep the scrape (amount, tension) and strain voices with sliders.
## A standalone test scene, not part of any level; nothing pauses. Space stops all, Esc quits.

const CUES: Array[StringName] = [
	&"click",
	&"click_muted",
	&"tick",
	&"clunk",
	&"creak",
	&"jam",
	&"snap",
	&"drop",
	&"open",
	&"relock",
]

var _audio: LockpickAudio
var _scrape: HSlider
var _tension: HSlider
var _strain: HSlider


func _ready() -> void:
	_audio = LockpickAudio.new()
	add_child(_audio)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Lockpicking sounds: keys 1-0 play cues, Space stops all, Esc quits"
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	column.add_child(grid)
	for i in CUES.size():
		var button := Button.new()
		button.text = "%d  %s" % [(i + 1) % 10, CUES[i]]
		button.custom_minimum_size = Vector2(180, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_audio.play.bind(CUES[i]))
		grid.add_child(button)
	_scrape = _add_slider(column, "Scraping (0..1)")
	_tension = _add_slider(column, "Tension (0..1): scrape pitch 2000-3600 Hz")
	_strain = _add_slider(column, "Strain (0..1): silent up to 0.12, pitch 260-1160 Hz")
	var stop := Button.new()
	stop.text = "Stop all"
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(_stop_all)
	column.add_child(stop)


func _process(_delta: float) -> void:
	_audio.set_scrape(_scrape.value, _tension.value)
	_audio.set_strain(_strain.value)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.keycode == KEY_SPACE:
		_stop_all()
	elif key.keycode >= KEY_0 and key.keycode <= KEY_9:
		var index := (key.keycode - KEY_0 + 9) % 10
		_audio.play(CUES[index])


func _stop_all() -> void:
	_scrape.value = 0.0
	_strain.value = 0.0
	_audio.stop_all()


func _add_slider(parent: Control, text: String) -> HSlider:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(600, 24)
	parent.add_child(slider)
	return slider
