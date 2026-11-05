extends VBoxContainer
## Debug panel tab: live EventLog entries, newest first, filterable by kind.

const MAX_VISIBLE_ENTRIES: int = 200

@onready var _filter: LineEdit = $Filter
@onready var _list: ItemList = $Entries


func _ready() -> void:
	_filter.text_changed.connect(_on_filter_changed)
	EventLog.entry_added.connect(_on_entry_added)
	_rebuild()


func _on_filter_changed(_text: String) -> void:
	_rebuild()


func _on_entry_added(entry: EventLogEntry) -> void:
	if _matches(entry):
		_prepend(entry)


func _rebuild() -> void:
	_list.clear()
	var matching: Array[EventLogEntry] = EventLog.entries().filter(_matches)
	for entry: EventLogEntry in matching.slice(-MAX_VISIBLE_ENTRIES):
		_prepend(entry)


func _prepend(entry: EventLogEntry) -> void:
	_list.move_item(_list.add_item(str(entry)), 0)
	if _list.item_count > MAX_VISIBLE_ENTRIES:
		_list.remove_item(_list.item_count - 1)


func _matches(entry: EventLogEntry) -> bool:
	return _filter.text.is_empty() or String(entry.kind).containsn(_filter.text)
