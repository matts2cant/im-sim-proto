class_name JournalTab
extends TabPage
## The Tab interface's Journal tab (ADR 0110; replaces the personal log screen of ADR 0060). A side
## list of three sections:
## - Objectives: the current mission's (Mission.of_level) title, a short briefing line and its
##   primary and secondary objectives with their state; outside a mission it says there is none.
## - Codes and logins: every code and login the player's PersonalLog knows, with what it opens
##   (LogEntry.code_label) and the entry it came from, a link that opens that note.
## - Notes: every entry, newest first (list), and the selected one (reader: title, source, text and
##   what it taught).
## Live: rebuilt while visible whenever the log or the mission's objectives change.

enum Section { OBJECTIVES, CODES, NOTES }

const SECTION_NAMES: Array[String] = ["Objectives", "Codes and logins", "Notes"]
const CODES_HINT := "Keypads and computers fill these in for you when you know them."
const NAV_WIDTH := 210.0
const LIST_WIDTH := 300.0

var player: Node
var personal_log: PersonalLog
var section: Section = Section.OBJECTIVES
## The entry the Notes reader shows (&"": the newest).
var note_id: StringName = &""

var _nav: VBoxContainer
var _body: HBoxContainer
var _nav_buttons: Array[Button] = []
var _signature: String = ""


func _ready() -> void:
	_build()


func tab_title() -> String:
	return "Journal"


func bind(p_player: Node) -> void:
	player = p_player
	personal_log = PersonalLog.of(player)
	refresh()


func on_shown() -> void:
	refresh()


func show_section(p_section: Section) -> void:
	section = p_section
	refresh()


## Shows entry `entry_id` in the Notes reader.
func open_note(entry_id: StringName) -> void:
	section = Section.NOTES
	note_id = entry_id
	refresh()


## The Mission of the player's level, or null.
func mission() -> Mission:
	return Mission.of_level(player) if is_instance_valid(player) else null


func objective_rows() -> Array[Dictionary]:
	var current := mission()
	if current == null or current.data == null:
		return []
	return JournalRules.objectives(current.data, current.tracker)


func code_rows() -> Array[Dictionary]:
	return JournalRules.codes(personal_log.book if personal_log != null else null)


## Entries, newest first.
func notes() -> Array[LogEntry]:
	return personal_log.entries() if personal_log != null else []


## The entry the reader shows, or null.
func shown_note() -> LogEntry:
	var list := notes()
	for entry in list:
		if entry.id == note_id:
			return entry
	return list[0] if not list.is_empty() else null


## Rebuilds the content when anything it shows changed.
func refresh() -> void:
	if _body == null:
		return
	var signature := _signature_now()
	if signature == _signature:
		return
	_signature = signature
	_rebuild()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


func _signature_now() -> String:
	var parts: PackedStringArray = [str(section), String(note_id), str(notes().size())]
	for row in objective_rows():
		parts.append("%s:%s" % [row["id"], row["done"]])
	return "|".join(parts)


func _rebuild() -> void:
	var counts: Array[int] = [objective_rows().size(), code_rows().size(), notes().size()]
	for i in _nav_buttons.size():
		TabStyle.style_row_button(_nav_buttons[i], i == section)
		(_nav_buttons[i].get_node(^"Count") as Label).text = str(counts[i])
	TabStyle.clear(_body)
	match section:
		Section.OBJECTIVES:
			_build_objectives()
		Section.CODES:
			_build_codes()
		Section.NOTES:
			_build_notes()


func _build_objectives() -> void:
	var column := TabStyle.column()
	column.name = "Objectives"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(column)
	var box := TabStyle.column_box(column)
	var current := mission()
	if current == null or current.data == null:
		var none := TabStyle.paragraph(JournalRules.NO_MISSION)
		none.name = "NoMission"
		box.add_child(none)
		return
	var title := TabStyle.label(current.data.title, 18)
	title.name = "MissionTitle"
	box.add_child(title)
	var briefing := TabStyle.paragraph(JournalRules.briefing_line(current.data.briefing))
	briefing.name = "Briefing"
	box.add_child(briefing)
	var rows := objective_rows()
	for optional: bool in [false, true]:
		box.add_child(TabStyle.caption("Secondary" if optional else "Primary"))
		for row in rows:
			if row["optional"] == optional:
				box.add_child(_objective(row))


func _objective(row: Dictionary) -> PanelContainer:
	var done: bool = row["done"]
	var optional: bool = row["optional"]
	var panel := PanelContainer.new()
	panel.name = "Objective_%s" % row["id"]
	# Its accent bar and state pill by state: JournalObjective* and JournalPill* (tab_theme.tres).
	var state := "Done" if done else ("Secondary" if optional else "Primary")
	TabStyle.themed(panel, StringName("JournalObjective" + state))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	box.add_child(head)
	var title := TabStyle.label(str(row["title"]), 15)
	title.name = "Title"
	head.add_child(title)
	var pill_text := "DONE" if done else ("SECONDARY" if optional else "PRIMARY")
	var pill_colour := TabStyle.OK if done else (TabStyle.CAPTION if optional else TabStyle.AMBER)
	var pill := PanelContainer.new()
	pill.name = "State"
	TabStyle.themed(pill, StringName("JournalPill" + state))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_label := TabStyle.mono(pill_text, 10, pill_colour)
	pill_label.name = "Text"
	pill.add_child(pill_label)
	head.add_child(pill)
	var description := str(row["description"])
	if not description.is_empty():
		box.add_child(TabStyle.paragraph(description, 13))
	return panel


func _build_codes() -> void:
	var column := TabStyle.column()
	column.name = "Codes"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(column)
	var box := TabStyle.column_box(column)
	box.add_child(TabStyle.caption("Codes and logins you know"))
	var rows := code_rows()
	if rows.is_empty():
		box.add_child(TabStyle.paragraph(JournalRules.NO_CODES))
		return
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 10)
	box.add_child(grid)
	for header: String in ["FOR", "CODE OR LOGIN", "LEARNED FROM"]:
		grid.add_child(TabStyle.mono(header, 11, TabStyle.CAPTION))
	for row in rows:
		grid.add_child(TabStyle.label(str(row["label"]), 13))
		grid.add_child(TabStyle.mono(str(row["value"]), 13, TabStyle.AMBER))
		var link := LinkButton.new()
		link.name = "From_%s" % row["code_id"]
		link.text = str(row["entry_title"])
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_color_override(&"font_color", TabStyle.CAPTION)
		link.add_theme_color_override(&"font_hover_color", TabStyle.AMBER)
		link.add_theme_font_size_override(&"font_size", 13)
		link.pressed.connect(open_note.bind(row["entry_id"]))
		grid.add_child(link)
	var hint := TabStyle.label(CODES_HINT, 12, TabStyle.DIM)
	box.add_child(hint)


func _build_notes() -> void:
	var list := notes()
	var shown := shown_note()
	var list_column := TabStyle.column(LIST_WIDTH)
	list_column.name = "List"
	_body.add_child(list_column)
	var list_box := TabStyle.column_box(list_column)
	list_box.add_theme_constant_override(&"separation", 4)
	for entry in list:
		var button := TabStyle.row_button("", entry == shown)
		button.name = "Note_%s" % String(entry.id).replace(".", "_")
		button.custom_minimum_size = Vector2(0, 50)
		# Title over a dim source line (a Button has one text colour).
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lines.offset_left = 10.0
		lines.offset_top = 7.0
		lines.add_theme_constant_override(&"separation", 2)
		var note_title := TabStyle.label(entry.title, 13, TabStyle.FG)
		note_title.name = "Title"
		lines.add_child(note_title)
		lines.add_child(TabStyle.mono(entry.source, 11, TabStyle.DIM))
		button.add_child(lines)
		button.pressed.connect(open_note.bind(entry.id))
		list_box.add_child(button)
	_body.add_child(TabStyle.divider())
	var reader := TabStyle.column()
	reader.name = "Reader"
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(reader)
	var box := TabStyle.column_box(reader)
	if shown == null:
		box.add_child(TabStyle.paragraph(JournalRules.EMPTY_LOG))
		return
	var title := TabStyle.label(shown.title, 18)
	title.name = "Title"
	box.add_child(title)
	var source := TabStyle.label(shown.source, 12, TabStyle.CAPTION)
	source.name = "Source"
	box.add_child(source)
	var text_panel := PanelContainer.new()
	TabStyle.themed(text_panel, &"TabTextBox")
	box.add_child(text_panel)
	var text := TabStyle.paragraph(shown.text if not shown.text.is_empty() else "(blank)", 14, TabStyle.FG)
	text.name = "Text"
	text_panel.add_child(text)
	var learned := JournalRules.learned_line(shown)
	if not learned.is_empty():
		var learned_label := TabStyle.paragraph(learned, 12, TabStyle.CAPTION)
		learned_label.name = "Learned"
		learned_label.label_settings.font = TabStyle.mono_font()
		box.add_child(learned_label)


func _build() -> void:
	var row := HBoxContainer.new()
	row.name = "Columns"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override(&"separation", 0)
	add_child(row)
	var nav_column := TabStyle.column(NAV_WIDTH)
	nav_column.name = "Nav"
	row.add_child(nav_column)
	_nav = TabStyle.column_box(nav_column)
	_nav.add_theme_constant_override(&"separation", 4)
	for i in SECTION_NAMES.size():
		var button := TabStyle.row_button(SECTION_NAMES[i], i == section)
		button.name = SECTION_NAMES[i].replace(" ", "")
		button.custom_minimum_size = Vector2(0, 36)
		var count := TabStyle.mono("", 11, TabStyle.DIM)
		count.name = "Count"
		count.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		button.add_child(count)
		button.pressed.connect(show_section.bind(i))
		_nav.add_child(button)
		_nav_buttons.append(button)
	row.add_child(TabStyle.divider())
	_body = HBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 0)
	row.add_child(_body)
