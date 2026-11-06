class_name Readable
extends Usable
## Component: text read in place (ADR 0060), on anything (a datapad, a note, a terminal). Using it
## (E, prompt "E: read <title>") passes its entry to the user's PersonalLog, which shows it and logs
## it once per `entry_id`. It never enters an inventory. A user without a PersonalLog cannot read.

## Stable and unique per readable: the log keeps one entry per id (and saves it by id).
@export var entry_id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""
## Keypad code id -> code (M8 keypads ask PersonalLog.known_code(code_id)).
@export var codes: Dictionary[StringName, String] = {}
## What the log says it was read from; empty: the owner's node name in words.
@export var source: String = ""


func _init() -> void:
	verb = "read"


func _ready() -> void:
	if entry_id == &"":
		push_warning("Readable %s has no entry_id: it cannot be logged" % get_path())


func target_name() -> String:
	return title


## What reading it adds to a log.
func entry() -> LogEntry:
	var from := source
	if from.is_empty() and get_parent() != null:
		from = String(get_parent().name).capitalize()
	return LogEntry.make(entry_id, title, text, from, codes)


func use(user: Node) -> bool:
	var reader_log := PersonalLog.of(user)
	if reader_log == null:
		return false
	var owner_node := get_parent()
	reader_log.read(entry(), String(owner_node.name) if owner_node != null else "")
	used.emit(user)
	return true
