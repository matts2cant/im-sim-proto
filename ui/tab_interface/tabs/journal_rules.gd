class_name JournalRules
extends RefCounted
## Pure texts of the Journal tab (ADR 0110): the mission's objectives with their state and a short
## briefing line, the codes and logins a PersonalLog knows (with a readable name for what each opens
## and the entry it came from), and the line of what an entry taught.

const NO_MISSION := "No mission running. Objectives show here during a mission."
const NO_CODES := "None yet. Codes and logins you read show here."
const EMPTY_LOG := "Nothing read yet. Look at a datapad and press E to read it."
## A short briefing line stops at the end of the sentence that reaches this length.
const BRIEFING_CHARS := 120


## One objective row: title, description, optional, done.
static func objectives(data: MissionData, tracker: ObjectiveTracker) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if data == null:
		return rows
	for optional: bool in [false, true]:
		for objective in data.objectives:
			if objective == null or objective.optional != optional:
				continue
			var done := tracker != null and tracker.is_done(objective.id)
			var row := {"id": objective.id, "title": objective.title, "description": objective.description}
			row["optional"] = objective.optional
			row["done"] = done
			rows.append(row)
	return rows


## The first sentences of `text`, up to the one that reaches BRIEFING_CHARS characters.
static func briefing_line(text: String) -> String:
	var clean := text.strip_edges()
	if clean.length() <= BRIEFING_CHARS:
		return clean
	var at := clean.find(". ", BRIEFING_CHARS - 1)
	return clean if at < 0 else clean.substr(0, at + 1)


## Every known code: label (what it opens), value (as shown), code_id, entry_id, entry_title; in the
## order they were learned. A code id holding logins (a computer's, ADR 0114) lists one row per user
## (the latest learned for that user); any other code, the latest one.
static func codes(book: LogBook) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if book == null:
		return rows
	for code_id in book.known_code_ids():
		var latest := book.code_entry(code_id)
		if latest == null:
			continue
		if LoginCredentials.parse(latest.codes[code_id]) == null:
			rows.append(_code_row(code_id, latest))
			continue
		var by_user: Dictionary[String, LogEntry] = {}
		for entry in book.code_entries(code_id):
			var login := LoginCredentials.parse(entry.codes[code_id])
			if login != null:
				by_user[login.user.to_lower()] = entry
		for user: String in by_user:
			rows.append(_code_row(code_id, by_user[user]))
	return rows


static func _code_row(code_id: StringName, entry: LogEntry) -> Dictionary:
	var row := {"label": entry.code_label(code_id), "value": code_value(entry.codes[code_id])}
	row["code_id"] = code_id
	row["entry_id"] = entry.id
	row["entry_title"] = entry.title
	return row


## A code as shown: a login ("user:password") as "user / password", anything else as it is.
static func code_value(raw: String) -> String:
	var login := LoginCredentials.parse(raw)
	return "%s / %s" % [login.user, login.password] if login != null else raw


## "Learned: Storage door 2817 · Office PC 2 login kbrandt / ferry19", or "" when it carries nothing.
static func learned_line(entry: LogEntry) -> String:
	if entry == null or entry.codes.is_empty():
		return ""
	var parts: PackedStringArray = []
	for code_id: StringName in entry.codes:
		parts.append("%s %s" % [entry.code_label(code_id), code_value(entry.codes[code_id])])
	return "Learned: " + " · ".join(parts)
