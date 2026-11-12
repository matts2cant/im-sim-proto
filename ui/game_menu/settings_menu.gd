class_name SettingsMenu
extends PanelContainer
## The Settings screen nested in the game menu (ADR 0120, ADR 0124): the game stays paused (it is
## part of the GameMenu's pause screen); Back or Esc returns to the game menu (GameMenu handles Esc).
## One row per GameSettings key, built from ROWS: a slider (value shown in display units) or a
## switch. Every change applies live through GameSettings.set_value(); the profile file is written
## when the screen closes (or leaves the tree).

## Back pressed (the game menu shows its buttons again).
signal back_requested

const HINT := "Esc: back"
const SECTION_COLOR := Color(0.55, 0.92, 0.88, 1)
const NAME_COLOR := Color(0.85, 0.95, 0.92, 1)
const NAME_FOCUS_COLOR := Color(1, 1, 1, 1)
const VALUE_COLOR := Color(0.5, 0.64, 0.64, 1)

## Columns of sections; each row: key, label, then for a slider [display min, display max, step,
## display units per setting unit, format of the shown value]; a switch has no more fields.
const COLUMNS: Array = [
	[
		[
			"Controls",
			[GameSettings.MOUSE_SENSITIVITY, "Mouse sensitivity", 0.25, 3.0, 0.05, 1.0, "%.2f×"],
			[GameSettings.INVERT_Y, "Invert Y"],
		],
		[
			"View",
			[GameSettings.FOV, "Field of view", 70.0, 100.0, 1.0, 1.0, "%d°"],
			[GameSettings.CAMERA_MOTION, "Camera motion", 0.0, 100.0, 5.0, 100.0, "%d %%"],
		],
	],
	[
		[
			"Audio",
			[GameSettings.MASTER_VOLUME, "Master volume", 0.0, 100.0, 5.0, 100.0, "%d %%"],
			[GameSettings.EFFECTS_VOLUME, "Effects volume", 0.0, 100.0, 5.0, 100.0, "%d %%"],
			[GameSettings.MUSIC_VOLUME, "Music volume", 0.0, 100.0, 5.0, 100.0, "%d %%"],
		],
		[
			"Display",
			[GameSettings.FULLSCREEN, "Fullscreen"],
			[GameSettings.VSYNC, "Vsync"],
		],
	],
]

var _sliders: Dictionary[StringName, HSlider] = {}
var _toggles: Dictionary[StringName, CheckButton] = {}
var _values: Dictionary[StringName, Label] = {}
var _formats: Dictionary[StringName, String] = {}
## Display units per setting unit (100 for a percentage).
var _units: Dictionary[StringName, float] = {}
## Set while refresh() writes the controls, so their signals do not write the settings back.
var _refreshing: bool = false

@onready var columns: HBoxContainer = %Columns
@onready var back_button: Button = %Back
@onready var hint_label: Label = %SettingsHint


func _ready() -> void:
	visible = false
	hint_label.text = HINT
	back_button.pressed.connect(back_requested.emit)
	for column: Array in COLUMNS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		for section: Array in column:
			_add_section(box, section)


func _exit_tree() -> void:
	GameSettings.save_if_changed()


func is_open() -> bool:
	return visible


## Shows the current settings and focuses the first control.
func open() -> void:
	refresh()
	visible = true
	first_control().grab_focus()


## Hides the screen and writes the profile if anything changed.
func close() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	GameSettings.save_if_changed()


## Writes the current settings into the controls.
func refresh() -> void:
	_refreshing = true
	for key: StringName in _sliders:
		_sliders[key].value = float(GameSettings.value(key)) * _units[key]
		_show_value(key)
	for key: StringName in _toggles:
		_toggles[key].button_pressed = bool(GameSettings.value(key))
	_refreshing = false


func first_control() -> Control:
	return _sliders[GameSettings.MOUSE_SENSITIVITY]


func slider(key: StringName) -> HSlider:
	return _sliders.get(key)


func toggle(key: StringName) -> CheckButton:
	return _toggles.get(key)


## The value shown next to a slider.
func value_text(key: StringName) -> String:
	return _values[key].text if _values.has(key) else ""


func _add_section(box: VBoxContainer, section: Array) -> void:
	var title := Label.new()
	title.text = section[0]
	title.label_settings = _label_settings(15, SECTION_COLOR)
	box.add_child(title)
	for i in range(1, section.size()):
		var row: Array = section[i]
		if row.size() > 2:
			_add_slider(box, row)
		else:
			_add_toggle(box, row)


func _add_slider(box: VBoxContainer, row: Array) -> void:
	var key: StringName = row[0]
	var line := _row(box, row[1])
	var name_label := line.get_child(0) as Label
	var bar := HSlider.new()
	bar.name = String(key)
	bar.min_value = row[2]
	bar.max_value = row[3]
	bar.step = row[4]
	bar.custom_minimum_size = Vector2(150, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.focus_mode = Control.FOCUS_ALL
	line.add_child(bar)
	var shown := Label.new()
	shown.custom_minimum_size = Vector2(56, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.label_settings = _label_settings(15, VALUE_COLOR)
	line.add_child(shown)
	_sliders[key] = bar
	_values[key] = shown
	_units[key] = row[5]
	_formats[key] = row[6]
	bar.value_changed.connect(_on_slider_changed.bind(key))
	_highlight_on_focus(bar, name_label)


func _add_toggle(box: VBoxContainer, row: Array) -> void:
	var key: StringName = row[0]
	var line := _row(box, row[1])
	var switch := CheckButton.new()
	switch.name = String(key)
	switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(switch)
	_toggles[key] = switch
	switch.toggled.connect(_on_toggled.bind(key))
	_highlight_on_focus(switch, line.get_child(0) as Label)


func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	box.add_child(line)
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.label_settings = _label_settings(16, NAME_COLOR)
	line.add_child(name_label)
	return line


# Sliders have no focus box: the focused row's name turns white instead.
func _highlight_on_focus(control: Control, name_label: Label) -> void:
	var normal := name_label.label_settings
	var focused := _label_settings(16, NAME_FOCUS_COLOR)
	focused.outline_size = 1
	focused.outline_color = NAME_FOCUS_COLOR
	control.focus_entered.connect(func() -> void: name_label.label_settings = focused)
	control.focus_exited.connect(func() -> void: name_label.label_settings = normal)


func _show_value(key: StringName) -> void:
	var format := _formats[key]
	var shown := _sliders[key].value
	_values[key].text = format % (roundi(shown) if format.contains("%d") else shown)


func _on_slider_changed(shown: float, key: StringName) -> void:
	_show_value(key)
	if not _refreshing:
		GameSettings.set_value(key, shown / _units[key])


func _on_toggled(on: bool, key: StringName) -> void:
	if not _refreshing:
		GameSettings.set_value(key, on)


static func _label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	return settings
