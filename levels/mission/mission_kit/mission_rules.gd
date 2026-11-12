class_name MissionRules
extends RefCounted
## Pure texts of the mission screens (ADR 0087): the briefing's objective list, toasts, the
## personal-log entries of objectives and the summary's rows.

const MAIN_PREFIX := "Objective"
const OPTIONAL_PREFIX := "Optional"
const COMPLETE := "%s complete: %s"
const GHOST := "Ghost"
const PACIFIST := "Pacifist"
const GHOST_RULE := "No guard alerted, no alarm, no body found"
const PACIFIST_RULE := "Nobody killed by you, directly or not"
const CLEAN_HANDS := "Clean hands"
const CLEAN_HANDS_RULE := "Nothing broken by you, directly or not"
## Each badge's rule, in display order.
const BADGE_RULES: Dictionary[String, String] = {
	GHOST: GHOST_RULE,
	PACIFIST: PACIFIST_RULE,
	CLEAN_HANDS: CLEAN_HANDS_RULE,
}
const LOG_SOURCE := "Briefing"


## "m:ss" (minutes not capped): 754.2 s -> "12:34".
static func time_text(seconds: float) -> String:
	var whole := maxi(int(floor(seconds)), 0)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


## "Objective" or "Optional".
static func prefix(objective: MissionObjective) -> String:
	return OPTIONAL_PREFIX if objective.optional else MAIN_PREFIX


## One briefing line: "Objective: Read the manifest" / "Optional: Take the prototype".
static func objective_line(objective: MissionObjective) -> String:
	return "%s: %s" % [prefix(objective), objective.title]


## The briefing's objective list, main objectives first, in data order otherwise.
static func objective_lines(objectives: Array[MissionObjective]) -> PackedStringArray:
	var lines := PackedStringArray()
	for optional: bool in [false, true]:
		for objective in objectives:
			if objective.optional == optional:
				lines.append(objective_line(objective))
	return lines


## The completion toast: "Objective complete: Read the manifest".
static func complete_text(objective: MissionObjective) -> String:
	return COMPLETE % [prefix(objective), objective.title]


## The personal-log entry of an objective (added at the start, ADR 0060's log).
static func log_entry(data: MissionData, objective: MissionObjective) -> LogEntry:
	var text := objective.description if not objective.description.is_empty() else objective.title
	return LogEntry.make(data.log_entry_id(objective), objective_line(objective), text, LOG_SOURCE)


## Shown at the extraction while a main objective is missing: its own hint, else the mission's.
static func extraction_hint(data: MissionData, missing: MissionObjective) -> String:
	if missing != null and not missing.extraction_hint.is_empty():
		return missing.extraction_hint
	return data.extraction_hint


## The summary's rows, label -> value, in display order.
static func summary_rows(results: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray(["Time", time_text(float(results.get("time", 0.0)))]))
	rows.append(PackedStringArray(["Alarms raised", str(int(results.get("alarms", 0)))]))
	rows.append(PackedStringArray(["Kills", str(int(results.get("kills", 0)))]))
	rows.append(PackedStringArray(["Knockouts", str(int(results.get("knockouts", 0)))]))
	var optional := "%d / %d" % [int(results.get("optional_done", 0)), int(results.get("optional_total", 0))]
	rows.append(PackedStringArray(["Optional objectives", optional]))
	return rows


## The badges earned, in order (Ghost, Pacifist, Clean hands).
static func badges(results: Dictionary) -> PackedStringArray:
	var earned := PackedStringArray()
	if bool(results.get("ghost", false)):
		earned.append(GHOST)
	if bool(results.get("pacifist", false)):
		earned.append(PACIFIST)
	if bool(results.get("clean_hands", false)):
		earned.append(CLEAN_HANDS)
	return earned
