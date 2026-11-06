class_name LogBook
extends RefCounted
## Pure logic of a PersonalLog (ADR 0060): the entries read, oldest first, one per entry id, and
## the codes they carried. Known codes are derived from the entries: when two entries carry the same
## code id, the one added last wins (newer information). Saved as the entry list only.

var entries: Array[LogEntry] = []

## Code id -> the entry that gave the code (the last one added that carries it).
var _code_entries: Dictionary[StringName, LogEntry] = {}


func has(entry_id: StringName) -> bool:
	return find(entry_id) != null


func find(entry_id: StringName) -> LogEntry:
	for entry in entries:
		if entry.id == entry_id:
			return entry
	return null


## Adds `entry` unless its id is empty or already logged. Returns true when it was added.
func add(entry: LogEntry) -> bool:
	if entry == null or entry.id == &"" or has(entry.id):
		return false
	entries.append(entry)
	for code_id: StringName in entry.codes:
		_code_entries[code_id] = entry
	return true


## Entries, newest first.
func newest_first() -> Array[LogEntry]:
	var list := entries.duplicate()
	list.reverse()
	return list


## The code known for keypad `code_id`, or "" when no entry read carried it.
func known_code(code_id: StringName) -> String:
	var entry: LogEntry = _code_entries.get(code_id)
	return entry.codes[code_id] if entry != null else ""


## The entry the code for `code_id` came from, or null.
func code_entry(code_id: StringName) -> LogEntry:
	return _code_entries.get(code_id)


## Known code ids, in the order they were first learned.
func known_code_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for code_id: StringName in _code_entries:
		ids.append(code_id)
	return ids


func clear() -> void:
	entries.clear()
	_code_entries.clear()


func to_dict() -> Dictionary:
	var list: Array[Dictionary] = []
	for entry in entries:
		list.append(entry.to_dict())
	return {"entries": list}


func from_dict(data: Dictionary) -> void:
	clear()
	for entry_data: Variant in data.get("entries", []):
		add(LogEntry.from_dict(entry_data as Dictionary))
