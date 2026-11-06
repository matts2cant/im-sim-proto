class_name SaveFile
extends RefCounted
## Save file format (ADR 0063): JSON text of `JSON.from_native(data)`, so Godot types (Vector3,
## Transform3D, StringName, int vs float, typed arrays and dictionaries) survive the round trip.
## Objects are never written nor read back (`JSON.to_native` without objects): a save file cannot
## make the game instantiate anything. Floats keep 17 digits; doubles can lose their last bit.
## A save is a Dictionary with a header ({version, level, saved_at}) next to the level snapshot.

## Outcome of reading, writing or (QuickSave) saving and loading. NO_LEVEL: no current level scene
## to save, or the saved level no longer exists; BUSY: a quickload is in progress.
enum Status { OK, MISSING, CORRUPT, WRONG_VERSION, UNWRITABLE, NO_LEVEL, BUSY }

## Bump when the saved data changes incompatibly; older saves are then refused, not migrated.
const VERSION: int = 1
## Keys every save has, with the Variant type each must be.
const REQUIRED: Dictionary[String, int] = {
	"version": TYPE_INT,
	"level": TYPE_STRING,
	"saved_at": TYPE_STRING,
}


class ReadResult:
	extends RefCounted
	var status: Status = Status.OK
	var data: Dictionary = {}

	func _init(p_status: Status, p_data: Dictionary = {}) -> void:
		status = p_status
		data = p_data


## The save text of `data` (tab-indented, so saves can be read and diffed).
static func encode(data: Dictionary) -> String:
	return JSON.stringify(JSON.from_native(data), "\t", false, true)


## Parses save text; CORRUPT when it is not a well-formed save, WRONG_VERSION when it is one of
## another version. Never prints an error for bad input.
static func decode(text: String) -> ReadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return ReadResult.new(Status.CORRUPT)
	var native: Variant = JSON.to_native(json.data)
	if not native is Dictionary:
		return ReadResult.new(Status.CORRUPT)
	var data: Dictionary = native
	if data.get("version") is int and int(data["version"]) != VERSION:
		return ReadResult.new(Status.WRONG_VERSION)
	for key: String in REQUIRED:
		if typeof(data.get(key)) != REQUIRED[key]:
			return ReadResult.new(Status.CORRUPT)
	return ReadResult.new(Status.OK, data)


## Writes `data` with the header filled in (version, level, saved_at).
static func write(path: String, level: String, data: Dictionary) -> Status:
	var full := {"version": VERSION, "level": level, "saved_at": Time.get_datetime_string_from_system(true)}
	full.merge(data)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return Status.UNWRITABLE
	file.store_string(encode(full))
	file.close()
	return Status.OK


static func read(path: String) -> ReadResult:
	if not FileAccess.file_exists(path):
		return ReadResult.new(Status.MISSING)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ReadResult.new(Status.CORRUPT)
	return decode(text)
