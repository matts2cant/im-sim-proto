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
## Code id -> a readable name for what the code opens ("Manager's office door"; ADR 0110). Codes
## without one are shown by their id in words.
var code_labels: Dictionary[StringName, String] = {}
## Exploits it taught (M12b, ADR 0116): the Journal's Exploits section and the deck's Exploits tool.
var exploits: Array[Exploit] = []


static func make(
	p_id: StringName,
	p_title: String,
	p_text: String,
	p_source: String = "",
	p_codes: Dictionary = {},
	p_code_labels: Dictionary = {},
	p_exploits: Array = []
) -> LogEntry:
	var entry := LogEntry.new()
	entry.id = p_id
	entry.title = p_title
	entry.text = p_text
	entry.source = p_source
	for code_id: Variant in p_codes:
		entry.codes[StringName(str(code_id))] = str(p_codes[code_id])
	for code_id: Variant in p_code_labels:
		entry.code_labels[StringName(str(code_id))] = str(p_code_labels[code_id])
	for exploit: Variant in p_exploits:
		if exploit is Exploit:
			entry.exploits.append(exploit as Exploit)
	return entry


## The readable name of what code `code_id` opens: its label, else the id in words.
func code_label(code_id: StringName) -> String:
	var label: String = code_labels.get(code_id, "")
	return label if not label.is_empty() else String(code_id).capitalize()


func to_dict() -> Dictionary:
	var code_data := {}
	for code_id: StringName in codes:
		code_data[String(code_id)] = codes[code_id]
	var label_data := {}
	for code_id: StringName in code_labels:
		label_data[String(code_id)] = code_labels[code_id]
	var data := {
		"entry_id": String(id),
		"title": title,
		"text": text,
		"source": source,
		"codes": code_data,
		"code_labels": label_data,
	}
	if not exploits.is_empty():
		var exploit_data: Array[Dictionary] = []
		for exploit in exploits:
			exploit_data.append(exploit.to_dict())
		data["exploits"] = exploit_data
	return data


static func from_dict(data: Dictionary) -> LogEntry:
	var exploits: Array[Exploit] = []
	for item: Variant in data.get("exploits", []) as Array:
		exploits.append(Exploit.from_dict(item as Dictionary))
	return make(
		StringName(str(data.get("entry_id", ""))),
		str(data.get("title", "")),
		str(data.get("text", "")),
		str(data.get("source", "")),
		data.get("codes", {}) as Dictionary,
		data.get("code_labels", {}) as Dictionary,
		exploits
	)
