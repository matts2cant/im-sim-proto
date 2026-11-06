class_name LogEntry
extends RefCounted
## One personal-log entry (ADR 0060): what a Readable held when it was read. `id` is stable and
## unique per readable (re-reading it adds nothing); `codes` maps a keypad's code id to its code.

var id: StringName = &""
var title: String = ""
var text: String = ""
## What it was read from ("Datapad").
var source: String = ""
## Keypad code id -> code.
var codes: Dictionary[StringName, String] = {}


static func make(
	p_id: StringName, p_title: String, p_text: String, p_source: String = "", p_codes: Dictionary = {}
) -> LogEntry:
	var entry := LogEntry.new()
	entry.id = p_id
	entry.title = p_title
	entry.text = p_text
	entry.source = p_source
	for code_id: Variant in p_codes:
		entry.codes[StringName(str(code_id))] = str(p_codes[code_id])
	return entry


func to_dict() -> Dictionary:
	var code_data := {}
	for code_id: StringName in codes:
		code_data[String(code_id)] = codes[code_id]
	return {"entry_id": String(id), "title": title, "text": text, "source": source, "codes": code_data}


static func from_dict(data: Dictionary) -> LogEntry:
	return make(
		StringName(str(data.get("entry_id", ""))),
		str(data.get("title", "")),
		str(data.get("text", "")),
		str(data.get("source", "")),
		data.get("codes", {}) as Dictionary
	)
