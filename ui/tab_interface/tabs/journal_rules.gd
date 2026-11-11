class_name JournalRules
extends RefCounted
## Pure texts of the Journal tab (ADR 0110): the mission's objectives with their state and a short
## briefing line, the codes and logins a PersonalLog knows (with a readable name for what each opens
## and the entry it came from), the exploits it knows (ADR 0116: what each targets, the access it
## grants, where it was learned), and the line of what an entry taught.

const NO_MISSION := "No mission running. Objectives show here during a mission."
const NO_CODES := "None yet. Codes and logins you read show here."
const NO_EXPLOITS := "None yet. Exploits you read about in mails, files and datapads show here."
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


## Every known exploit: id, title, targets ("Helix CAM-3 2.0–2.1"), access ("admin"), entry_id,
## entry_title and entry_source (where it was learned); in the order learned.
static func exploits(book: LogBook) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if book == null:
		return rows
	for exploit in book.known_exploits():
		var entry := book.exploit_entry(exploit.id)
		var row := {"id": exploit.id, "title": exploit.title, "targets": exploit.targets()}
		row["access"] = exploit.access_name()
		row["entry_id"] = entry.id if entry != null else &""
		row["entry_title"] = entry.title if entry != null else ""
		row["entry_source"] = entry.source if entry != null else ""
		rows.append(row)
	return rows


## "Exploit Helix default service login (Helix CAM-3 2.0–2.1, admin)".
static func exploit_text(exploit: Exploit) -> String:
	return "exploit %s (%s, %s)" % [exploit.title, exploit.targets(), exploit.access_name()]


## A code as shown: a login ("user:password") as "user / password", anything else as it is.
static func code_value(raw: String) -> String:
	var login := LoginCredentials.parse(raw)
	return "%s / %s" % [login.user, login.password] if login != null else raw


## "Learned: Storage door 2817 · Office PC 2 login kbrandt / ferry19 · exploit Helix default service
## login (Helix CAM-3 2.0–2.1, admin)", or "" when it carries nothing.
static func learned_line(entry: LogEntry) -> String:
	if entry == null or (entry.codes.is_empty() and entry.exploits.is_empty()):
		return ""
	var parts: PackedStringArray = []
	for code_id: StringName in entry.codes:
		parts.append("%s %s" % [entry.code_label(code_id), code_value(entry.codes[code_id])])
	for exploit in entry.exploits:
		parts.append(exploit_text(exploit))
	return "Learned: " + " · ".join(parts)
