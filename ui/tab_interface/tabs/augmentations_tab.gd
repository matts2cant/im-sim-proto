class_name AugmentationsTab
extends TabPage
## Tab interface page: the character's augmentations (ADR 0111). The energy bar and charge, the total
## drain of what is on and the seconds left at that drain; one card per key slot (F1-F5): name,
## description, drain per second, a switch (Augmentations.toggle_slot(), the F-keys' path; switching
## on at 0 energy is refused with "Energy depleted") and "N s alone" while on. Slots with nothing
## installed are greyed ("Not installed"). Installed passive augmentations follow, without a switch.
## Works for any character with Augmentations and Energy. The world keeps running: the page refreshes
## itself every frame while visible.

## Key slots shown (aug_1 ... aug_<n>).
@export var slot_count: int = 5
## Seconds a feedback line ("Energy depleted") stays.
@export var message_seconds: float = 2.5

var entity: Node

var _augmentations: Augmentations
var _energy: Energy
var _energy_bar: ProgressBar
var _energy_value: Label
var _drain_label: Label
var _cards: Dictionary[int, PanelContainer] = {}
var _keys: Dictionary[int, Label] = {}
var _names: Dictionary[int, Label] = {}
var _descriptions: Dictionary[int, Label] = {}
var _switches: Dictionary[int, CheckButton] = {}
var _side_labels: Dictionary[int, Label] = {}
var _passive_list: VBoxContainer
var _message: Label
var _message_left: float = 0.0
var _built: bool = false
var _card_on := CharacterTabStyle.box(CharacterTabStyle.ENERGY_BG, CharacterTabStyle.ENERGY, 5)
var _card_off := CharacterTabStyle.box(CharacterTabStyle.CLEAR, CharacterTabStyle.LINE, 5)


func tab_title() -> String:
	return "Augmentations"


func bind(player: Node) -> void:
	entity = player
	_augmentations = Augmentations.of(entity)
	_energy = Energy.of(entity)
	if _augmentations != null and not _augmentations.message.is_connected(show_message):
		_augmentations.message.connect(show_message)
	if not _built:
		_build()
	refresh()


func on_shown() -> void:
	refresh()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0 and _message != null:
			_message.text = ""
	if is_visible_in_tree():
		refresh()


## The augmentation in `slot` that is installed, or null.
func installed_in(slot: int) -> AugmentationData:
	if _augmentations == null:
		return null
	var data := _augmentations.in_slot(slot)
	return data if data != null and _augmentations.is_installed(data.id) else null


## Switches the augmentation in `slot` on or off the way its F-key does; returns whether it is on.
func set_slot_on(slot: int, on: bool) -> bool:
	var data := installed_in(slot)
	if data == null:
		refresh()
		return false
	if _augmentations.is_active(data.id) != on:
		_augmentations.toggle_slot(slot)
	refresh()
	return _augmentations.is_active(data.id)


## Energy per second drained by what is on.
func drain_rate() -> float:
	return _augmentations.drain_rate() if _augmentations != null else 0.0


## "12 s left at 4 / s", or "No drain".
func drain_text() -> String:
	var rate := drain_rate()
	if rate <= 0.0 or _energy == null:
		return "No drain"
	return "%d s left at %s / s" % [floori(_energy.current() / rate), CharacterTabStyle.number(rate)]


## The text under a slot's switch: "4 energy / s", plus "· 25 s alone" while on.
func slot_side_text(slot: int) -> String:
	var data := installed_in(slot)
	if data == null:
		return "needs an augmentation canister"
	var text := "%s energy / s" % CharacterTabStyle.number(data.drain_per_second)
	if _augmentations.is_active(data.id) and data.drain_per_second > 0.0 and _energy != null:
		text += "  ·  %d s alone" % floori(_energy.current() / data.drain_per_second)
	return text


func show_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message_left = message_seconds


func refresh() -> void:
	if not _built:
		return
	if _energy != null:
		_energy_bar.value = _energy.fraction()
		_energy_value.text = "%d / %d" % [CharacterTabStyle.whole(_energy.current()), roundi(_energy.maximum())]
	_drain_label.text = drain_text()
	for slot: int in _cards:
		_refresh_card(slot)
	_refresh_passive()


func _refresh_card(slot: int) -> void:
	var assigned := _augmentations.in_slot(slot) if _augmentations != null else null
	var data := installed_in(slot)
	var on := data != null and _augmentations.is_active(data.id)
	var card := _cards[slot]
	var key_label := assigned.key_label() if assigned != null else "F%d" % slot
	if _keys[slot].text != key_label:
		_keys[slot].text = key_label
	_names[slot].text = assigned.display_name if assigned != null else "Empty slot"
	_descriptions[slot].text = data.description if data != null else "Not installed."
	_switches[slot].visible = data != null
	_switches[slot].set_pressed_no_signal(on)
	_side_labels[slot].text = slot_side_text(slot)
	card.modulate.a = 1.0 if data != null else 0.45
	var style := _card_on if on else _card_off
	if card.get_theme_stylebox(&"panel") != style:
		card.add_theme_stylebox_override(&"panel", style)
	var key_color := CharacterTabStyle.ENERGY if on else CharacterTabStyle.CAPTION
	_keys[slot].add_theme_color_override(&"font_color", key_color)


func _refresh_passive() -> void:
	var passive: Array[AugmentationData] = []
	if _augmentations != null:
		for data in _augmentations.catalog:
			if data != null and data.passive and _augmentations.is_installed(data.id):
				passive.append(data)
	var labels := _passive_list.get_children()
	for i in maxi(passive.size(), labels.size()):
		if i >= labels.size():
			var line := CharacterTabStyle.paragraph("", 13, CharacterTabStyle.FG)
			_passive_list.add_child(line)
			labels.append(line)
		var label := labels[i] as Label
		label.visible = i < passive.size()
		if label.visible:
			label.text = "Passive  ·  %s: %s" % [passive[i].display_name, passive[i].description]


func _build() -> void:
	_built = true
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var holder := HBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	var column := CharacterTabStyle.column(holder, 0.0, true)
	column.add_theme_constant_override(&"separation", 8)

	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override(&"separation", 16)
	column.add_child(energy_row)
	energy_row.add_child(CharacterTabStyle.label("Energy", 14, CharacterTabStyle.CAPTION))
	_energy_bar = CharacterTabStyle.bar(14.0, 320.0)
	_energy_bar.name = "EnergyBar"
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_row.add_child(_energy_bar)
	_energy_value = CharacterTabStyle.label("")
	_energy_value.name = "EnergyValue"
	energy_row.add_child(_energy_value)
	_drain_label = CharacterTabStyle.label("", 14, CharacterTabStyle.CAPTION)
	_drain_label.name = "Drain"
	energy_row.add_child(_drain_label)

	for slot in range(1, slot_count + 1):
		column.add_child(_card(slot))
	_passive_list = VBoxContainer.new()
	column.add_child(_passive_list)
	var note := "Click a switch or press its F key in play. At 0 energy every augmentation switches off."
	column.add_child(CharacterTabStyle.paragraph(note + " A bioelectric cell restores energy.", 12))
	_message = CharacterTabStyle.label("", 13, CharacterTabStyle.AMBER)
	_message.name = "Message"
	column.add_child(_message)


func _card(slot: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Slot%d" % slot
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)
	var key_box := PanelContainer.new()
	key_box.custom_minimum_size = Vector2(52, 0)
	key_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_box.add_theme_stylebox_override(
		&"panel", CharacterTabStyle.box(CharacterTabStyle.CLEAR, CharacterTabStyle.LINE_STRONG)
	)
	var key := CharacterTabStyle.label("F%d" % slot, 14, CharacterTabStyle.CAPTION)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_box.add_child(key)
	row.add_child(key_box)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	var title := CharacterTabStyle.label("", 15)
	text.add_child(title)
	var description := CharacterTabStyle.paragraph("")
	text.add_child(description)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 200.0
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var switch := CheckButton.new()
	switch.name = "Switch"
	switch.focus_mode = Control.FOCUS_NONE
	switch.size_flags_horizontal = Control.SIZE_SHRINK_END
	switch.toggled.connect(func(on: bool) -> void: set_slot_on(slot, on))
	side.add_child(switch)
	var side_label := CharacterTabStyle.label("", 12, CharacterTabStyle.CAPTION)
	side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(side_label)
	_cards[slot] = card
	_keys[slot] = key
	_names[slot] = title
	_descriptions[slot] = description
	_switches[slot] = switch
	_side_labels[slot] = side_label
	return card
