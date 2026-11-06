class_name GameMenuRules
extends RefCounted
## Texts of the game menu (ADR 0064): the line under Load ("Saved 14:32 · Hub", or why there is
## nothing to load) and the feedback for a save or load that did not happen.

const NO_SAVE := "No save"
const MESSAGES: Dictionary[SaveFile.Status, String] = {
	SaveFile.Status.MISSING: NO_SAVE,
	SaveFile.Status.CORRUPT: "Save is damaged",
	SaveFile.Status.WRONG_VERSION: "Save is from another version",
	SaveFile.Status.UNWRITABLE: "Could not write the save",
	SaveFile.Status.NO_LEVEL: "Saved level not found",
	SaveFile.Status.BUSY: "Loading",
}


## Player-facing text for a save or load status other than OK.
static func message(status: SaveFile.Status) -> String:
	return MESSAGES.get(status, NO_SAVE)


## "Saved 14:32 · Hub": the save header's time (stored in UTC, shown `utc_offset` seconds later)
## and its level's name. Without a readable time: "Saved · Hub".
static func slot_line(header: Dictionary, utc_offset: int) -> String:
	var level := level_name(str(header.get("level", "")))
	var time := local_time(str(header.get("saved_at", "")), utc_offset)
	return "Saved %s · %s" % [time, level] if not time.is_empty() else "Saved · %s" % level


## "HH:MM" of an ISO UTC date-time ("2026-11-06T13:32:10") moved by `utc_offset` seconds; "" when
## the text is not one.
static func local_time(saved_at: String, utc_offset: int) -> String:
	if not RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$").search(saved_at):
		return ""
	var unix := Time.get_unix_time_from_datetime_string(saved_at) + utc_offset
	return Time.get_time_string_from_unix_time(unix).substr(0, 5)


## "Hub" for res://levels/hub/hub.tscn, "Flat Floor" for flat_floor.tscn.
static func level_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename().capitalize()


## Seconds the system's local time is ahead of UTC, rounded to the minute.
static func system_utc_offset() -> int:
	var local := Time.get_unix_time_from_datetime_string(Time.get_datetime_string_from_system(false))
	var utc := Time.get_unix_time_from_datetime_string(Time.get_datetime_string_from_system(true))
	return roundi((local - utc) / 60.0) * 60
