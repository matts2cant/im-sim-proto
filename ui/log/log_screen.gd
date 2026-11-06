class_name LogScreen
extends CanvasLayer
## The player's personal log (child of the Player, ADR 0060). `personal_log` (L) toggles it, Esc
## closes it; it pauses the game like the inventory (PauseScreens, ADR 0052) and does not open over
## another pause screen, while dead or with the debug panel open. Left: entry titles, newest first,
## and the known codes with the entry each came from; right: the selected entry's title and text
## (the mouse wheel scrolls long text).

const EMPTY_TEXT := "Nothing read yet. Look at a datapad and press E to read it."
const NO_CODES := "None yet"

var player: Player
var personal_log: PersonalLog

## Entries as listed (newest first).
var _shown: Array[LogEntry] = []

@onready var entry_list: ItemList = %Entries
@onready var codes_label: Label = %Codes
@onready var title_label: Label = %Title
@onready var text_label: RichTextLabel = %Text


func _ready() -> void:
	visible = false
	add_to_group(PauseScreens.GROUP)
	entry_list.item_selected.connect(select)
	player = get_parent() as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	personal_log = PersonalLog.of(player)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


func can_open() -> bool:
	return (
		player != null
		and personal_log != null
		and player.input_enabled
		and ActorState.can_act(player)
		and not DebugPanel.is_open()
		and not PauseScreens.any_open(get_tree())
	)


func open() -> void:
	if visible or not can_open():
		return
	refresh()
	visible = true
	PauseScreens.update(get_tree())


func close() -> void:
	if not visible:
		return
	visible = false
	PauseScreens.update(get_tree())
	player.resync_actions()


## Rebuilds the entry list and codes from the log and selects the newest entry.
func refresh() -> void:
	_shown = personal_log.entries()
	entry_list.clear()
	for entry in _shown:
		entry_list.add_item(entry.title)
	codes_label.text = codes_text(personal_log)
	if _shown.is_empty():
		title_label.text = ""
		text_label.text = EMPTY_TEXT
		return
	entry_list.select(0)
	select(0)


## Shows entry `index` of the list (0 = newest).
func select(index: int) -> void:
	if index < 0 or index >= _shown.size():
		return
	title_label.text = _shown[index].title
	text_label.text = _shown[index].text if not _shown[index].text.is_empty() else "(blank)"
	text_label.scroll_to_line(0)


## The title of the entry shown on the right ("" when none).
func shown_title() -> String:
	return title_label.text


## One line per known code: "Storage door: 2817  (Storage access)".
static func codes_text(reader_log: PersonalLog) -> String:
	var lines: PackedStringArray = []
	for code_id in reader_log.known_code_ids():
		var code := reader_log.known_code(code_id)
		lines.append("%s: %s  (%s)" % [String(code_id).capitalize(), code, reader_log.code_source(code_id)])
	return "\n".join(lines) if not lines.is_empty() else NO_CODES


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"personal_log"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
