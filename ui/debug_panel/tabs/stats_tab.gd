class_name StatsTab
extends VBoxContainer
## Debug panel tab: the skills, augmentations and energy of an entity (the Player registers it for
## itself; ADR 0061). No leveling in v0: a tier picker per skill, an installed checkbox and an on/off
## toggle per augmentation, an energy slider and "Refill energy". Changes apply live through the
## components' APIs; the controls follow changes made elsewhere (F-keys, biocells, drain).

## The entity whose Skills, Augmentations and Energy are shown.
var entity: Node

var _built_for: Node
var _tier_pickers: Dictionary[StringName, OptionButton] = {}
var _installed_boxes: Dictionary[StringName, CheckBox] = {}
var _active_buttons: Dictionary[StringName, CheckButton] = {}
var _energy_slider: HSlider
var _energy_label: Label


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


## Builds the controls for `entity` (once) and shows its current state.
func refresh() -> void:
	if not is_instance_valid(entity):
		return
	if _built_for != entity:
		_build()
	var skills := Skills.of(entity)
	if skills != null:
		for skill: StringName in _tier_pickers:
			var picker := _tier_pickers[skill]
			if picker.selected != skills.tier(skill):
				picker.select(skills.tier(skill))
	var augmentations := Augmentations.of(entity)
	if augmentations != null:
		for id: StringName in _installed_boxes:
			_installed_boxes[id].set_pressed_no_signal(augmentations.is_installed(id))
		for id: StringName in _active_buttons:
			var button := _active_buttons[id]
			button.set_pressed_no_signal(augmentations.is_active(id))
			var data := augmentations.find(id)
			button.disabled = not augmentations.is_installed(id) or (data != null and data.passive)
	var energy := Energy.of(entity)
	if energy != null:
		_energy_slider.max_value = energy.maximum()
		_energy_slider.set_value_no_signal(energy.current())
		_energy_label.text = "Energy %.1f / %.0f" % [energy.current(), energy.maximum()]


## Sets a skill tier (the picker does this).
func set_tier(skill: StringName, tier: int) -> void:
	var skills := Skills.of(entity)
	if skills != null:
		skills.set_tier(skill, tier)


func set_installed(id: StringName, installed: bool) -> void:
	var augmentations := Augmentations.of(entity)
	if augmentations != null:
		augmentations.set_installed(id, installed)


func set_active(id: StringName, active: bool) -> void:
	var augmentations := Augmentations.of(entity)
	if augmentations == null:
		return
	if active:
		augmentations.activate(id)
	else:
		augmentations.deactivate(id)


func set_energy(value: float) -> void:
	var energy := Energy.of(entity)
	if energy != null:
		energy.set_current(value)


func refill_energy() -> void:
	var energy := Energy.of(entity)
	if energy != null:
		energy.refill()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tier_pickers.clear()
	_installed_boxes.clear()
	_active_buttons.clear()
	_built_for = entity
	_build_skills()
	_build_augmentations()
	_build_energy()


func _build_skills() -> void:
	var skills := Skills.of(entity)
	if skills == null or skills.table == null:
		return
	_header("Skills")
	var grid := GridContainer.new()
	grid.columns = 2
	add_child(grid)
	for skill in skills.table.skills:
		var label := Label.new()
		label.text = skill.display_name
		label.tooltip_text = skill.description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(label)
		var picker := OptionButton.new()
		picker.name = "Tier_%s" % skill.id
		for tier in skills.table.tier_names.size():
			picker.add_item(skills.table.tier_name(tier), tier)
		picker.select(skills.tier(skill.id))
		picker.item_selected.connect(_on_tier_selected.bind(skill.id))
		grid.add_child(picker)
		_tier_pickers[skill.id] = picker


func _build_augmentations() -> void:
	var augmentations := Augmentations.of(entity)
	if augmentations == null:
		return
	_header("Augmentations")
	var grid := GridContainer.new()
	grid.columns = 3
	add_child(grid)
	for data in augmentations.catalog:
		var label := Label.new()
		label.text = HudRules.chip_text(data) if not data.passive else "%s (passive)" % data.display_name
		label.tooltip_text = data.description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(label)
		var installed := CheckBox.new()
		installed.name = "Installed_%s" % data.id
		installed.text = "installed"
		installed.toggled.connect(_on_installed_toggled.bind(data.id))
		grid.add_child(installed)
		_installed_boxes[data.id] = installed
		var active := CheckButton.new()
		active.name = "Active_%s" % data.id
		active.text = "on"
		active.toggled.connect(_on_active_toggled.bind(data.id))
		grid.add_child(active)
		_active_buttons[data.id] = active


func _build_energy() -> void:
	if Energy.of(entity) == null:
		return
	_header("Energy")
	_energy_label = Label.new()
	add_child(_energy_label)
	_energy_slider = HSlider.new()
	_energy_slider.name = "EnergySlider"
	_energy_slider.min_value = 0.0
	_energy_slider.step = 1.0
	_energy_slider.custom_minimum_size = Vector2(240, 0)
	_energy_slider.value_changed.connect(set_energy)
	add_child(_energy_slider)
	var refill := Button.new()
	refill.name = "Refill"
	refill.text = "Refill energy"
	refill.pressed.connect(refill_energy)
	add_child(refill)


func _header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(1, 0.84, 0.45))
	add_child(label)


func _on_tier_selected(index: int, skill: StringName) -> void:
	set_tier(skill, index)


func _on_installed_toggled(pressed: bool, id: StringName) -> void:
	set_installed(id, pressed)


func _on_active_toggled(pressed: bool, id: StringName) -> void:
	set_active(id, pressed)
