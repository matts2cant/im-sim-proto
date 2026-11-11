class_name LogBook
extends RefCounted
## Pure logic of a PersonalLog (ADR 0060): the entries read, oldest first, one per entry id, and
## the codes and exploits (ADR 0116) they carried. Known codes and exploits are derived from the
## entries: when two entries carry the same code id (or exploit id), the one added last wins (newer
## information). Saved as the entry list only.

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


## Every entry that carried `code_id`, in the order they were added (a computer's code id can
## carry several logins, one per entry: ADR 0114).
func code_entries(code_id: StringName) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry in entries:
		if entry.codes.has(code_id):
			found.append(entry)
	return found


## Every known exploit, one per id (the latest entry's), in the order first learned.
func known_exploits() -> Array[Exploit]:
	var by_id: Dictionary[StringName, Exploit] = {}
	for entry in entries:
		for exploit in entry.exploits:
			if exploit != null:
				by_id[exploit.id] = exploit
	var found: Array[Exploit] = []
	for exploit_id: StringName in by_id:
		found.append(by_id[exploit_id])
	return found


## The entry the exploit `exploit_id` was learned from (the latest), or null.
func exploit_entry(exploit_id: StringName) -> LogEntry:
	var found: LogEntry = null
	for entry in entries:
		for exploit in entry.exploits:
			if exploit != null and exploit.id == exploit_id:
				found = entry
	return found


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
