class_name HealthTab
extends TabPage
## Tab interface page: the character's body (ADR 0111). A clickable silhouette and one row per part
## (health bar, value / max, what happens at 0 from the body profile); the current effects from the
## body and the state tags; treatment with the healing items carried: how many and how much one
## heals (with the user's scale attribute, Medicine for a medkit), "Use a medkit on the <part>"
## (PlayerInventory.use_stack() with the part: the item's stimuli touch that part's hitbox) and
## "Heal all" (the belt's use: spread over the hurt parts). Works for any character with BodyParts;
## treatment needs a PlayerInventory. The world keeps running: the page refreshes itself every frame while visible.

## Display name per body part.
@export var part_names: Dictionary[StringName, String] = {
	&"head": "Head",
	&"torso": "Torso",
	&"arm_l": "Left arm",
	&"arm_r": "Right arm",
	&"leg_l": "Left leg",
	&"leg_r": "Right leg",
}
## State tags listed under Current effects, with their text (the injury tags have their own wording).
@export var tag_effects: Dictionary[StringName, String] = {
	&"state.burning": "Burning",
	&"state.unconscious": "Unconscious",
	&"state.cloaked": "Cloaked: guards cannot see you",
}
## Use stimulus that makes an item a healing item (a medkit's `heal`).
@export var heal_stimulus: StringName = &"heal"
## Seconds a feedback line ("Healed 30", "You are not hurt") stays.
@export var message_seconds: float = 2.5

var entity: Node
## The part the treatment button acts on.
var selected: StringName = BodyDamageModel.TORSO

var _body: BodyParts
var _tags: Tags
var _inventory: PlayerInventory
var _picker: BodyPartPicker
var _rows: Dictionary[StringName, PanelContainer] = {}
var _bars: Dictionary[StringName, ProgressBar] = {}
var _values: Dictionary[StringName, Label] = {}
var _zero_lines: Dictionary[StringName, Label] = {}
var _effects: VBoxContainer
var _no_effects: Label
var _treatment: Label
var _heal_part_button: Button
var _heal_all_button: Button
var _message: Label
var _message_left: float = 0.0
var _built: bool = false
var _row_plain := CharacterTabStyle.row_style(false)
var _row_selected := CharacterTabStyle.row_style(true)


func tab_title() -> String:
	return "Health"


func bind(player: Node) -> void:
	entity = player
	_body = BodyParts.of(entity)
	_tags = ActorState.tags_of(entity)
	_inventory = _find_inventory(entity)
	if _inventory != null and not _inventory.message.is_connected(show_message):
		_inventory.message.connect(show_message)
	if not _built:
		_build()
	refresh()


## Selects the most hurt part when the selected one is unhurt (opening the page to treat a wound).
func on_shown() -> void:
	if _body != null and not _body.model.is_damaged(selected):
		var worst := selected
		for part in BodyDamageModel.PARTS:
			if _body.model.ratio(part) < _body.model.ratio(worst):
				worst = part
		selected = worst
	refresh()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0 and _message != null:
			_message.text = ""
	if is_visible_in_tree():
		refresh()


func select_part(part: StringName) -> void:
	if BodyDamageModel.PARTS.has(part):
		selected = part
		refresh()


## Healing items carried (medkits).
func medkit_count() -> int:
	return HealthTabRules.count(_healing_stacks())


## Health one of them restores now (30 x the Medicine multiplier for a medkit).
func heal_per_use() -> float:
	var stacks := _healing_stacks()
	if stacks.is_empty():
		return 0.0
	return HealthTabRules.heal_amount(stacks[0].item, heal_stimulus, entity)


## "Use a medkit on the <part>": one healing item on the selected part. False when refused (the
## part is unhurt: the item is kept and the item's message shows) or there is none.
func heal_selected() -> bool:
	var stacks := _healing_stacks()
	if stacks.is_empty():
		return false
	var before := _body.health(selected)
	var used := _inventory.use_stack(stacks[0], selected)
	if used:
		_report_healed(_body.health(selected) - before)
	refresh()
	return used


## "Heal all": one healing item used as from the belt, spread over the hurt parts.
func heal_all() -> bool:
	var stacks := _healing_stacks()
	if stacks.is_empty():
		return false
	var before := _total_health()
	var used := _inventory.use_stack(stacks[0])
	if used:
		_report_healed(_total_health() - before)
	refresh()
	return used


func show_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message_left = message_seconds


## The texts under Current effects.
func effect_texts() -> PackedStringArray:
	return HealthTabRules.current_effects(_body, _tags, tag_effects)


## "22 / 60" for a part.
func value_text(part: StringName) -> String:
	if _body == null:
		return ""
	return "%d / %d" % [CharacterTabStyle.whole(_body.health(part)), roundi(_body.model.max_health(part))]


## The colour a part's bar and silhouette block show (HudRules.part_color()).
func part_color(part: StringName) -> Color:
	return _picker.part_color(part)


func refresh() -> void:
	if not _built or _body == null:
		return
	_picker.body = _body
	_picker.selected = selected
	_picker.queue_redraw()
	for part in BodyDamageModel.PARTS:
		var ratio := _body.model.ratio(part)
		_bars[part].value = ratio
		CharacterTabStyle.set_bar_color(_bars[part], HudRules.part_color(ratio))
		_values[part].text = value_text(part)
		_zero_lines[part].visible = _body.model.is_disabled(part)
		var style := _row_selected if part == selected else _row_plain
		if _rows[part].get_theme_stylebox(&"panel") != style:
			_rows[part].add_theme_stylebox_override(&"panel", style)
	_refresh_effects()
	_refresh_treatment()


func _refresh_effects() -> void:
	var texts := effect_texts()
	var labels := _effects.get_children()
	for i in maxi(texts.size(), labels.size()):
		if i >= labels.size():
			var line := CharacterTabStyle.label("", 14, CharacterTabStyle.BAD)
			_effects.add_child(line)
			labels.append(line)
		var label := labels[i] as Label
		label.visible = i < texts.size()
		if label.visible and label.text != texts[i]:
			label.text = texts[i]
	_no_effects.visible = texts.is_empty()


func _refresh_treatment() -> void:
	var count := medkit_count()
	var stacks := _healing_stacks()
	var skill := ""
	if not stacks.is_empty():
		skill = HealthTabRules.skill_note(entity, stacks[0].item.use_scale_attribute)
	_treatment.text = (
		"Medkits: %d  ·  each heals %s%s"
		% [count, CharacterTabStyle.number(heal_per_use()), " (%s)" % skill if not skill.is_empty() else ""]
	)
	var alive := not _body.is_dead()
	var part_name: String = part_names.get(selected, String(selected))
	_heal_part_button.text = "Use a medkit on the %s" % part_name.to_lower()
	_heal_part_button.disabled = count == 0 or not alive or not _body.model.is_damaged(selected)
	_heal_all_button.disabled = count == 0 or not alive or not BodyDamageModel.PARTS.any(_body.model.is_damaged)


func _healing_stacks() -> Array[ItemStack]:
	if _inventory == null or _inventory.inventory == null:
		return []
	return HealthTabRules.healing_stacks(_inventory.inventory.stacks, heal_stimulus)


func _total_health() -> float:
	var total := 0.0
	for part in BodyDamageModel.PARTS:
		total += _body.health(part)
	return total


func _report_healed(amount: float) -> void:
	show_message("Healed %s" % CharacterTabStyle.number(amount))


func _find_inventory(node: Node) -> PlayerInventory:
	if node == null:
		return null
	for child in node.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null


func _build() -> void:
	_built = true
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override(&"separation", 0)
	add_child(columns)

	var left := CharacterTabStyle.column(columns, 300.0)
	left.add_child(CharacterTabStyle.heading("Body"))
	_picker = BodyPartPicker.new()
	_picker.name = "BodyPicker"
	_picker.custom_minimum_size = Vector2(150, 330)
	_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker.part_clicked.connect(select_part)
	left.add_child(_picker)
	var hint := CharacterTabStyle.label("Click a body part to treat it.", 12, CharacterTabStyle.CAPTION)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(hint)

	columns.add_child(CharacterTabStyle.separator())
	var right := CharacterTabStyle.column(columns, 0.0, true)
	right.add_child(CharacterTabStyle.heading("Body parts"))
	var parts := VBoxContainer.new()
	parts.add_theme_constant_override(&"separation", 2)
	right.add_child(parts)
	for part in BodyDamageModel.PARTS:
		parts.add_child(_part_row(part))

	right.add_child(CharacterTabStyle.spacer(6))
	right.add_child(CharacterTabStyle.heading("Current effects"))
	_effects = VBoxContainer.new()
	_effects.add_theme_constant_override(&"separation", 2)
	right.add_child(_effects)
	_no_effects = CharacterTabStyle.label("None.", 14, CharacterTabStyle.CAPTION)
	right.add_child(_no_effects)

	right.add_child(CharacterTabStyle.spacer(6))
	right.add_child(CharacterTabStyle.heading("Treatment"))
	_treatment = CharacterTabStyle.label("", 14, CharacterTabStyle.CAPTION)
	_treatment.name = "Treatment"
	right.add_child(_treatment)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	right.add_child(buttons)
	_heal_part_button = CharacterTabStyle.button("Use a medkit", true)
	_heal_part_button.name = "HealPart"
	_heal_part_button.pressed.connect(heal_selected)
	buttons.add_child(_heal_part_button)
	_heal_all_button = CharacterTabStyle.button("Heal all (spread over hurt parts)")
	_heal_all_button.name = "HealAll"
	_heal_all_button.pressed.connect(heal_all)
	buttons.add_child(_heal_all_button)
	_message = CharacterTabStyle.label("", 13, CharacterTabStyle.AMBER)
	_message.name = "Message"
	right.add_child(_message)


func _part_row(part: StringName) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Part_%s" % part
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(part))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(line)
	var title := CharacterTabStyle.label(part_names.get(part, String(part)))
	title.custom_minimum_size.x = 100.0
	line.add_child(title)
	var bar := CharacterTabStyle.bar(10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	var value := CharacterTabStyle.label("", 13, CharacterTabStyle.CAPTION)
	value.custom_minimum_size.x = 70.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value)
	var zero_text := HealthTabRules.disabled_text(part, _body.profile) if _body != null else ""
	var zero := CharacterTabStyle.label("Disabled: %s" % zero_text, 12, CharacterTabStyle.BAD)
	zero.visible = false
	lines.add_child(zero)
	_rows[part] = row
	_bars[part] = bar
	_values[part] = value
	_zero_lines[part] = zero
	return row


func _on_row_input(event: InputEvent, part: StringName) -> void:
	if CharacterTabStyle.is_click(event):
		select_part(part)
