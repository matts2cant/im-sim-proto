class_name SkillsTab
extends TabPage
## Tab interface page: the character's skills (ADR 0111). Each skill with tier pips and its tier name;
## the selected one shows its description and what every tier gives, built from the skill data
## (SkillData.tier_rows(): each effect's label and per-tier value), the current tier highlighted.
## TESTING controls: - / + change the tier through Skills.set_tier() (the debug panel's path) until
## M18 replaces them with experience; the Experience box is a placeholder until then. Works for any
## character with Skills. The world keeps running: the page refreshes itself every frame while visible.

var entity: Node
## The skill whose details are shown.
var selected: StringName = &""

var _skills: Skills
var _rows: Dictionary[StringName, PanelContainer] = {}
var _pips: Dictionary[StringName, Array] = {}
var _tier_labels: Dictionary[StringName, Label] = {}
var _title: Label
var _description: Label
var _tier_value: Label
var _down: Button
var _up: Button
var _table: GridContainer
var _empty_table: Label
var _shown_skill: StringName = &""
var _shown_tier: int = -1
var _built: bool = false
var _row_plain := CharacterTabStyle.row_style(false)
var _row_selected := CharacterTabStyle.row_style(true)
var _pip_on := CharacterTabStyle.box(CharacterTabStyle.AMBER, CharacterTabStyle.AMBER, 0)
var _pip_off := CharacterTabStyle.box(CharacterTabStyle.WELL, CharacterTabStyle.LINE_STRONG, 0)
var _cell_current := _cell_style(CharacterTabStyle.SELECTED_BG)
var _cell_plain := _cell_style(CharacterTabStyle.CLEAR)


func tab_title() -> String:
	return "Skills"


func bind(player: Node) -> void:
	entity = player
	_skills = Skills.of(entity)
	if selected.is_empty() and _skills != null and not _skills.skill_ids().is_empty():
		selected = _skills.skill_ids()[0]
	if not _built:
		_build()
	refresh()


func on_shown() -> void:
	refresh()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


func select_skill(skill: StringName) -> void:
	if _skills != null and _skills.skill_ids().has(skill):
		selected = skill
		refresh()


## TESTING: raises (+1) or lowers (-1) the selected skill's tier, clamped Untrained..Master.
func change_tier(step: int) -> void:
	if _skills != null and not selected.is_empty():
		_skills.set_tier(selected, _skills.tier(selected) + step)
	refresh()


## The tier table shown for the selected skill: a header row, then each effect's row.
func table_texts() -> Array[PackedStringArray]:
	var texts: Array[PackedStringArray] = []
	var row := PackedStringArray()
	for child in _table.get_children():
		row.append((child.get_child(0) as Label).text)
		if row.size() == _table.columns:
			texts.append(row)
			row = PackedStringArray()
	return texts


func refresh() -> void:
	if not _built or _skills == null:
		return
	for skill: StringName in _rows:
		var tier := _skills.tier(skill)
		var style := _row_selected if skill == selected else _row_plain
		if _rows[skill].get_theme_stylebox(&"panel") != style:
			_rows[skill].add_theme_stylebox_override(&"panel", style)
		var pips: Array = _pips[skill]
		for i in pips.size():
			var pip := pips[i] as Panel
			var pip_style := _pip_on if tier > i else _pip_off
			if pip.get_theme_stylebox(&"panel") != pip_style:
				pip.add_theme_stylebox_override(&"panel", pip_style)
		_tier_labels[skill].text = _skills.table.tier_name(tier)
	var current := _skills.tier(selected)
	if selected != _shown_skill or current != _shown_tier:
		_show_details(current)


func _show_details(tier: int) -> void:
	_shown_skill = selected
	_shown_tier = tier
	var data := _skills.table.find(selected)
	if data == null:
		return
	_title.text = data.display_name
	_description.text = data.description
	_tier_value.text = _skills.table.tier_name(tier)
	_down.disabled = tier <= SkillTable.UNTRAINED
	_up.disabled = tier >= SkillTable.MASTER
	# The cells hold no signals: free them at once (no stale cells, no orphans until the frame ends).
	for child in _table.get_children():
		child.free()
	var names := _skills.table.tier_names
	var rows := data.tier_rows(names.size())
	_empty_table.visible = rows.is_empty()
	_table.visible = not rows.is_empty()
	if rows.is_empty():
		return
	var header := PackedStringArray([""])
	header.append_array(names)
	rows.push_front(header)
	for r in rows.size():
		for c in rows[r].size():
			var current := c == tier + 1
			var color := CharacterTabStyle.AMBER if current else CharacterTabStyle.FG
			if r == 0 or c == 0:
				color = CharacterTabStyle.AMBER if current else CharacterTabStyle.CAPTION
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override(&"panel", _cell_current if current else _cell_plain)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var text := CharacterTabStyle.label(rows[r][c], 12 if r == 0 else 13, color)
			if c == 0:
				text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				text.custom_minimum_size.x = 128.0
			cell.add_child(text)
			_table.add_child(cell)


func _build() -> void:
	_built = true
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override(&"separation", 0)
	add_child(columns)

	var left := CharacterTabStyle.column(columns, 340.0)
	left.add_child(CharacterTabStyle.heading("Skills"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	left.add_child(list)
	if _skills != null:
		for skill in _skills.skill_ids():
			list.add_child(_skill_row(skill))
	left.add_child(CharacterTabStyle.spacer(6))
	left.add_child(CharacterTabStyle.heading("Experience"))
	left.add_child(CharacterTabStyle.placeholder("XP shows here and buys tiers in M18."))

	columns.add_child(CharacterTabStyle.separator())
	var right := CharacterTabStyle.column(columns, 0.0, true)
	_title = CharacterTabStyle.label("", 18)
	right.add_child(_title)
	_description = CharacterTabStyle.paragraph("")
	right.add_child(_description)
	var testing := HBoxContainer.new()
	testing.add_theme_constant_override(&"separation", 8)
	right.add_child(testing)
	var tag := PanelContainer.new()
	var tag_style := CharacterTabStyle.box(CharacterTabStyle.CLEAR, CharacterTabStyle.WARN, 3)
	tag_style.content_margin_top = 1.0
	tag_style.content_margin_bottom = 1.0
	tag_style.content_margin_left = 5.0
	tag_style.content_margin_right = 5.0
	tag.add_theme_stylebox_override(&"panel", tag_style)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(CharacterTabStyle.label("TESTING", 10, CharacterTabStyle.WARN))
	testing.add_child(tag)
	_down = CharacterTabStyle.button("−")
	_down.name = "TierDown"
	_down.tooltip_text = "Lower tier"
	_down.pressed.connect(change_tier.bind(-1))
	testing.add_child(_down)
	_tier_value = CharacterTabStyle.label("", 13)
	_tier_value.custom_minimum_size.x = 76.0
	_tier_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	testing.add_child(_tier_value)
	_up = CharacterTabStyle.button("+")
	_up.name = "TierUp"
	_up.tooltip_text = "Raise tier"
	_up.pressed.connect(change_tier.bind(1))
	testing.add_child(_up)
	testing.add_child(CharacterTabStyle.label("until M18 replaces this with XP", 12, CharacterTabStyle.CAPTION))
	right.add_child(CharacterTabStyle.spacer(4))
	right.add_child(CharacterTabStyle.heading("What each tier gives"))
	_table = GridContainer.new()
	_table.name = "TierTable"
	_table.columns = (_skills.table.tier_names.size() if _skills != null else 4) + 1
	_table.add_theme_constant_override(&"h_separation", 0)
	_table.add_theme_constant_override(&"v_separation", 0)
	right.add_child(_table)
	_empty_table = CharacterTabStyle.label("Nothing yet.", 13, CharacterTabStyle.CAPTION)
	right.add_child(_empty_table)


func _skill_row(skill: StringName) -> PanelContainer:
	var data := _skills.table.find(skill)
	var row := PanelContainer.new()
	row.name = "Skill_%s" % skill
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(skill))
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var title := CharacterTabStyle.label(data.display_name, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override(&"separation", 4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pips)
	var pip_nodes: Array = []
	for i in _skills.table.tier_names.size() - 1:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(22, 8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		pip_nodes.append(pip)
	var tier := CharacterTabStyle.label("", 12, CharacterTabStyle.CAPTION)
	tier.custom_minimum_size.x = 76.0
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(tier)
	_rows[skill] = row
	_pips[skill] = pip_nodes
	_tier_labels[skill] = tier
	return row


static func _cell_style(bg: Color) -> StyleBoxFlat:
	var style := CharacterTabStyle.box(bg, CharacterTabStyle.CLEAR, 0)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _on_row_input(event: InputEvent, skill: StringName) -> void:
	if CharacterTabStyle.is_click(event):
		select_skill(skill)
