class_name DocumentApp
extends HBoxContainer
## Halcyon OS's Mail and Files apps (ADR 0114): a list (subject and sender, or file name) and a
## reader (title, sender, text, what reading it taught). Selecting an item reads it: it joins the
## viewer's PersonalLog like a datapad (Computer.read(), source "Mail" or "Files"), without the
## reading overlay. An implicit clue is kept as a note: nothing is learned. The first item is
## selected (read) when the app shows.

const LIST_WIDTH: float = 300.0
const NOTE_ONLY := "Added to the Journal (Notes)."
const CLUE := "A clue, not a login: nothing is learned. Added to the Journal (Notes); type your guess."
const EMPTY_MAIL := "No mail."
const EMPTY_FILES := "No files."

var computer: Computer
var viewer: Node
## "Mail" or "Files": the PersonalLog source and the list's caption.
var source: String = "Mail"
var documents: Array[ComputerDocument] = []
var selected: int = -1

var list_caption: Label
var title_label: Label
var from_label: Label
var reader_label: Label
var learned_label: Label

var _list: VBoxContainer
var _buttons: Array[Button] = []
var _reader_box: PanelContainer


func _ready() -> void:
	_build()


## Shows `p_documents` of `p_computer` for `p_viewer` and reads the first one.
func show_documents(
	p_computer: Computer, p_viewer: Node, p_documents: Array[ComputerDocument], p_source: String
) -> void:
	computer = p_computer
	viewer = p_viewer
	source = p_source
	documents = p_documents
	selected = -1
	list_caption.text = ("Inbox" if source == "Mail" else "Files").to_upper()
	_rebuild_list()
	select(0)


## The list's titles, in order.
func titles() -> Array[String]:
	var names: Array[String] = []
	for item in documents:
		names.append(item.title)
	return names


## Selects (and reads) item `index`; false when there is none.
func select(index: int) -> bool:
	if index < 0 or index >= documents.size():
		_show_reader(null)
		return false
	selected = index
	var item := documents[index]
	if computer != null:
		computer.read(item, viewer, source)
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == index)
	_show_reader(item)
	return true


## Selects the item titled `title`; false when none is.
func select_title(title: String) -> bool:
	return select(titles().find(title))


## The list entry of item `index`, or null.
func entry(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null


func _show_reader(item: ComputerDocument) -> void:
	_reader_box.visible = item != null
	if item == null:
		title_label.text = EMPTY_MAIL if source == "Mail" else EMPTY_FILES
		from_label.text = ""
		learned_label.text = ""
		return
	title_label.text = item.title
	from_label.text = "From %s" % item.sender if not item.sender.is_empty() else ""
	from_label.visible = not item.sender.is_empty()
	reader_label.text = item.text
	learned_label.text = learned_text(item)
	learned_label.label_settings.font_color = HalcyonStyle.AMBER if _teaches(item) else HalcyonStyle.DIM


## What reading `item` taught, as the reader's last line.
static func learned_text(item: ComputerDocument) -> String:
	if item.implicit_clue:
		return CLUE
	var line := JournalRules.learned_line(item.entry(""))
	return line + " · added to the Journal." if not line.is_empty() else NOTE_ONLY


static func _teaches(item: ComputerDocument) -> bool:
	return not item.implicit_clue and not item.codes.is_empty()


func _rebuild_list() -> void:
	for child in _list.get_children():
		HalcyonStyle.discard(child)
	_buttons.clear()
	for i in documents.size():
		var item := documents[i]
		var text := item.title
		if not item.sender.is_empty():
			text += "\n" + item.sender
		var button := HalcyonStyle.list_entry(text)
		button.name = "Item%d" % i
		button.clip_text = true
		button.custom_minimum_size = Vector2(LIST_WIDTH - 40.0, 0)
		button.pressed.connect(select.bind(i))
		_list.add_child(button)
		_buttons.append(button)


func _build() -> void:
	add_theme_constant_override(&"separation", 0)
	var left := MarginContainer.new()
	left.name = "List"
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	_margins(left, 16)
	add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override(&"separation", 8)
	left.add_child(left_box)
	list_caption = HalcyonStyle.caption("Inbox")
	left_box.add_child(list_caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)
	add_child(HalcyonStyle.rule(true))
	var right := MarginContainer.new()
	right.name = "Reader"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margins(right, 18)
	add_child(right)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 8)
	right_scroll.add_child(column)
	title_label = HalcyonStyle.label("", 18, HalcyonStyle.TEAL)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)
	from_label = HalcyonStyle.label("", 12, HalcyonStyle.DIM)
	column.add_child(from_label)
	_reader_box = PanelContainer.new()
	_reader_box.add_theme_stylebox_override(
		&"panel", HalcyonStyle.box(Color(0.55, 0.95, 0.85, 0.03), HalcyonStyle.LINE, 1, 4, 14)
	)
	column.add_child(_reader_box)
	reader_label = HalcyonStyle.paragraph("", 14, HalcyonStyle.TEXT)
	reader_label.custom_minimum_size = Vector2(380, 0)
	_reader_box.add_child(reader_label)
	learned_label = HalcyonStyle.paragraph("", 12, HalcyonStyle.DIM)
	learned_label.label_settings.font = TabStyle.mono_font()
	column.add_child(learned_label)


static func _margins(node: MarginContainer, value: int) -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, value)
