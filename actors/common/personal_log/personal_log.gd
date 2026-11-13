class_name PersonalLog
extends Node
## Component of any actor (ADR 0060): what its owner has read. A Readable it uses (a datapad read
## in place) is passed to read(): the reading overlay shows every read (`entry_read`), a new entry
## id is added once (`entry_added`, EventLog `log.entry_added`) and the codes it carries become
## known. M8 keypads ask known_code(code_id) / code_source(code_id). Pure logic in LogBook.
## Saveable (group `saveable`).

## Every read, new or not (the reading overlay shows it).
signal entry_read(entry: LogEntry)
## A new entry was added (the HUD says "Added to log").
signal entry_added(entry: LogEntry)

var book: LogBook = LogBook.new()


static func of(node: Node) -> PersonalLog:
	if node == null:
		return null
	for child in node.get_children():
		if child is PersonalLog:
			return child as PersonalLog
	return null


func _ready() -> void:
	add_to_group(&"saveable")


## The owner read `entry` (from the entity named `from`). Returns true when it was new.
func read(entry: LogEntry, from: String = "") -> bool:
	var added := add(entry, from)
	entry_read.emit(entry)
	return added


## Adds `entry` without it being read (nothing opens): a mission's objectives (ADR 0087). Logged
## and signalled like a new read. Returns true when it was new.
func add(entry: LogEntry, from: String = "") -> bool:
	if not book.add(entry):
		return false
	var code_ids: Array[String] = []
	for code_id: StringName in entry.codes:
		code_ids.append(String(code_id))
	var data := {"entry_id": String(entry.id), "title": entry.title, "codes": code_ids}
	EventLog.record(EventKinds.LOG_ENTRY_ADDED, _who(), from, data)
	entry_added.emit(entry)
	return true


func has(entry_id: StringName) -> bool:
	return book.has(entry_id)


## Entries, newest first.
func entries() -> Array[LogEntry]:
	return book.newest_first()


## The code read for keypad `code_id`, or "" when none is known.
func known_code(code_id: StringName) -> String:
	return book.known_code(code_id)


## Title of the entry the code for `code_id` came from, or "" when none is known.
func code_source(code_id: StringName) -> String:
	var entry := book.code_entry(code_id)
	return entry.title if entry != null else ""


## Every entry that carried a code for `code_id`, oldest first.
func code_entries(code_id: StringName) -> Array[LogEntry]:
	return book.code_entries(code_id)


func known_code_ids() -> Array[StringName]:
	return book.known_code_ids()


func save_state() -> Dictionary:
	return book.to_dict()


func load_state(data: Dictionary) -> void:
	book.from_dict(data)


func _who() -> String:
	var owner_node := get_parent()
	return String(owner_node.name) if owner_node != null else String(name)
