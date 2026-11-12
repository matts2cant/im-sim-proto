class_name TuningPanel
extends CanvasLayer
## The shooting range's live tuning panel (ADR 0125), opened by a TuningDesk. A plain debug tool in
## the shared window frame (WindowFrame, Halcyon look) on the right of the screen: the world keeps
## running and stays visible (no pause, no dim); while open the user's input is off, the mouse is
## free and the HUD hidden. Esc or the ✕ closes it, and so does the user walking or being pushed
## away from the desk or no longer able to act.
## Contents, for the weapon in the user's hand (WeaponSkill.weapon_of()): the Weapons skill tier
## buttons for the skill that trains it (Skills.set_tier()), then every `@export_range` float / int
## of the weapon's WeaponData and of each Resource it references (TuningProperties, by reflection:
## no property names here), one slider each that changes the live resource at once; "Save" writes
## the resources back to their .tres files (editor and dev runs only) and "Revert" reloads the saved
## values. Without a weapon in hand it says so.

signal closed

const LAYER: int = 24
## The panel's anchors: the right part of the screen, so the range stays in view.
const AREA := Rect2(0.46, 0.06, 0.51, 0.88)
const HINT := "Esc: close · the world keeps running"
const SAVE_NOTE := "Save writes the .tres files: only in the editor or a run from the project folder."
const NO_WEAPON := "Draw a gun to tune it."
const NAME_WIDTH: float = 180.0
const VALUE_WIDTH: float = 64.0

## The node using it.
var user: Node
var player: Player
## The weapon whose tuning is shown, or null.
var weapon: WeaponData
## The node the user must stay near (the desk's entity), or null.
var anchor: Node3D
var max_distance: float = 3.0

var panel: WindowFrame
var weapon_label: Label
var tier_label: Label
var tier_buttons: Array[Button] = []
var list: VBoxContainer
var save_button: Button
var revert_button: Button
var status_label: Label

# "<entry label>/<property>" -> slider, value label.
var _sliders: Dictionary[String, HSlider] = {}
var _values: Dictionary[String, Label] = {}
var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hud_before: bool = true
var _filling: bool = false


func _ready() -> void:
	visible = false
	layer = LAYER
	_build()


func _exit_tree() -> void:
	if visible:
		close()


func is_open() -> bool:
	return visible


## Opens the panel for `p_user` (the weapon in its hand), kept open while it stays within
## `p_max_distance` of `p_anchor` (null: anywhere).
func open_for(p_user: Node, p_anchor: Node3D = null, p_max_distance: float = 3.0) -> void:
	if visible:
		close()
	user = p_user
	player = p_user as Player
	anchor = p_anchor
	max_distance = p_max_distance
	visible = true
	if player != null:
		_input_before = player.input_enabled
		player.input_enabled = false
		var hud := player.get_node_or_null(^"Hud") as CanvasLayer
		if hud != null:
			_hud_before = hud.visible
			hud.visible = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rebuild()


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(player):
		var hud := player.get_node_or_null(^"Hud") as CanvasLayer
		if hud != null:
			hud.visible = _hud_before
		player.input_enabled = _input_before
		player.resync_actions()
	Input.mouse_mode = _mouse_before
	user = null
	player = null
	closed.emit()


## Refills the panel for the weapon in the user's hand.
func rebuild() -> void:
	weapon = WeaponSkill.weapon_of(user) if is_instance_valid(user) else null
	for child in list.get_children():
		HalcyonStyle.discard(child)
	_sliders.clear()
	_values.clear()
	status_label.text = SAVE_NOTE
	if weapon == null:
		weapon_label.text = NO_WEAPON
		panel.subtitle_label.text = ""
		_refresh_tiers()
		save_button.disabled = true
		revert_button.disabled = true
		return
	weapon_label.text = weapon.display_name
	panel.subtitle_label.text = weapon.resource_path
	save_button.disabled = false
	revert_button.disabled = false
	for entry in TuningProperties.entries(weapon):
		var rows := TuningProperties.sliders(entry.resource)
		if rows.is_empty():
			continue
		var where := entry.resource.resource_path if TuningProperties.is_file(entry.resource) else "embedded"
		var title := entry.label if not entry.label.is_empty() else String(weapon.id)
		list.add_child(HalcyonStyle.caption("%s  (%s)" % [title, where]))
		for row in rows:
			list.add_child(_slider_row(entry, row))
	_refresh_tiers()
	_fill()


## The slider of property `property` of the entry labelled `entry_label` ("" for the weapon itself,
## "aim_config", ...), or null.
func slider(entry_label: String, property: String) -> HSlider:
	return _sliders.get("%s/%s" % [entry_label, property])


## Every slider key ("<entry label>/<property>"), in panel order.
func slider_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_sliders.keys())
	return keys


## Writes the weapon's resources to their files; the status line says what happened.
func save() -> void:
	if weapon == null:
		return
	var failed := TuningProperties.save(weapon)
	status_label.text = "Saved." if failed.is_empty() else "Could not save: %s" % ", ".join(failed)


## Restores the saved values.
func revert() -> void:
	if weapon == null:
		return
	var count := TuningProperties.revert(weapon)
	_fill()
	status_label.text = "Reverted %d resources to their saved values." % count


## Sets the user's tier of the skill training the weapon (a tier button does this).
func set_tier(tier: int) -> void:
	WeaponSkill.set_tier(user, tier)
	_refresh_tiers()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(user) or not ActorState.can_act(user):
		close()
		return
	var body := user as Node3D
	if anchor != null and body != null and body.global_position.distance_to(anchor.global_position) > max_distance:
		close()
		return
	if WeaponSkill.weapon_of(user) != weapon:
		rebuild()


func _slider_row(entry: TuningProperties.Entry, row: TuningProperties.RangeProperty) -> HBoxContainer:
	var key := "%s/%s" % [entry.label, row.name]
	var box := HBoxContainer.new()
	box.name = key.replace("/", "__").replace(".", "_")
	box.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	var name_label := HalcyonStyle.label(row.name, 13)
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.clip_text = true
	box.add_child(name_label)
	var bar := HSlider.new()
	bar.theme_type_variation = &"HalcyonSlider"
	bar.focus_mode = Control.FOCUS_NONE
	bar.min_value = row.min_value
	bar.max_value = row.max_value
	bar.step = row.step
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.value_changed.connect(_on_slider_changed.bind(entry.resource, row, key))
	box.add_child(bar)
	var value := HalcyonStyle.label("", 13, HalcyonStyle.TEAL, true)
	value.custom_minimum_size.x = VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(value)
	_sliders[key] = bar
	_values[key] = value
	bar.set_meta(&"resource", entry.resource)
	bar.set_meta(&"property", row.name)
	return box


# Shows the resources' current values without writing them back.
func _fill() -> void:
	_filling = true
	for key: String in _sliders:
		var bar := _sliders[key]
		var resource := bar.get_meta(&"resource") as Resource
		var value: Variant = resource.get(bar.get_meta(&"property") as String)
		bar.value = float(value)
		_values[key].text = _format(value)
	_filling = false


func _on_slider_changed(value: float, resource: Resource, row: TuningProperties.RangeProperty, key: String) -> void:
	if _filling:
		return
	TuningProperties.set_value(resource, row, value)
	_values[key].text = _format(resource.get(row.name))


func _refresh_tiers() -> void:
	var skill := WeaponSkill.skill_of(user) if is_instance_valid(user) else &""
	var tier := WeaponSkill.tier(user) if not skill.is_empty() else -1
	tier_label.text = WeaponSkill.describe(user) if tier >= 0 else "No skill trains this weapon"
	for i in tier_buttons.size():
		tier_buttons[i].disabled = tier < 0
		tier_buttons[i].set_pressed_no_signal(i == tier)


static func _format(value: Variant) -> String:
	if value is int:
		return str(value)
	return "%.3f" % float(value)


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = WindowFrame.new(&"Halcyon")
	panel.name = "Panel"
	panel.set_sidebar_visible(false)
	panel.anchor_left = AREA.position.x
	panel.anchor_top = AREA.position.y
	panel.anchor_right = AREA.end.x
	panel.anchor_bottom = AREA.end.y
	panel.title_label.text = "Weapon tuning"
	panel.close_button.tooltip_text = "Close (Esc)"
	panel.close_requested.connect(close)
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.theme_type_variation = &"WindowBody"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.body.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	margin.add_child(column)
	weapon_label = HalcyonStyle.label("", 16, HalcyonStyle.TEAL)
	weapon_label.name = "Weapon"
	column.add_child(weapon_label)
	_build_tiers(column)
	column.add_child(HalcyonStyle.rule())
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_xs"))
	scroll.add_child(list)
	column.add_child(HalcyonStyle.rule())
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	column.add_child(actions)
	save_button = HalcyonStyle.button("Save", true)
	save_button.name = "Save"
	save_button.pressed.connect(save)
	actions.add_child(save_button)
	revert_button = HalcyonStyle.button("Revert")
	revert_button.name = "Revert"
	revert_button.pressed.connect(revert)
	actions.add_child(revert_button)
	actions.add_child(HalcyonStyle.label(HINT, 12, HalcyonStyle.DIM))
	status_label = HalcyonStyle.paragraph(SAVE_NOTE, 12, HalcyonStyle.DIM)
	status_label.name = "Status"
	column.add_child(status_label)


# The skill line ("Pistols: Trained"), then a row of one button per tier.
func _build_tiers(column: VBoxContainer) -> void:
	tier_label = HalcyonStyle.label("", 13)
	tier_label.name = "Skill"
	column.add_child(tier_label)
	var row := HBoxContainer.new()
	row.name = "Tiers"
	row.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	column.add_child(row)
	var names := SkillTable.new().tier_names
	for i in names.size():
		var button := HalcyonStyle.list_entry(names[i])
		button.name = names[i]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(set_tier.bind(i))
		tier_buttons.append(button)
		row.add_child(button)
