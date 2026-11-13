extends GdUnitTestSuite
## EventKinds (ADR 0136): one definition of every EventLog kind. Kinds are unique, the ones `core/`
## records itself are its own constants, no gameplay code records a kind as a string literal, and
## no kind is also a tag (S25: kinds name events, tags name states; both are dotted).
## EventLogEntry keeps the entities an entry names (by reference, never by name).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const StimulusSystemScript := preload("res://core/stimulus/stimulus_system.gd")
## Source folders scanned for emitters (tests and addons are not game code).
const SOURCE_DIRS: Array[String] = ["res://actors", "res://core", "res://events", "res://items", "res://levels"]
const MORE_SOURCE_DIRS: Array[String] = ["res://objects", "res://ui"]


static func _kinds() -> Dictionary[String, StringName]:
	var found: Dictionary[String, StringName] = {}
	var constants := (EventKinds as Script).get_script_constant_map()
	for constant: String in constants:
		if constants[constant] is StringName:
			found[constant] = constants[constant]
	return found


static func _files(dir: String, extensions: Array[String], out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_files(dir.path_join(sub), extensions, out)
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in extensions:
			out.append(dir.path_join(file))


func test_every_kind_is_unique_and_dotted() -> void:
	var kinds := _kinds()
	var seen: Dictionary[StringName, String] = {}
	for constant in kinds:
		var kind := kinds[constant]
		assert_bool(seen.has(kind)).override_failure_message("%s duplicates %s" % [constant, seen.get(kind)]).is_false()
		seen[kind] = constant
		assert_str(String(kind)).override_failure_message(constant).contains(".")
	assert_int(kinds.size()).is_greater(100)


func test_core_kinds_are_cores_own_constants() -> void:
	assert_str(EventKinds.STIMULUS_EMITTED).is_equal(StimulusSystemScript.EMITTED_KIND)
	assert_str(EventKinds.STIMULUS_DROPPED).is_equal(StimulusSystemScript.DROPPED_KIND)
	assert_str(EventKinds.STIMULUS_RECEIVED).is_equal(StimulusReceiver.RECEIVED_KIND)
	assert_str(EventKinds.RECEPTRON_FIRED).is_equal(StimulusReceiver.FIRED_KIND)
	assert_str(EventKinds.GAME_SAVED).is_equal(QuickSave.SAVED_KIND)
	assert_str(EventKinds.GAME_LOADED).is_equal(QuickSave.LOADED_KIND)
	assert_str(EventKinds.LEVEL_RESET).is_equal(LevelReset.RESET_KIND)


func test_no_code_records_a_kind_literal() -> void:
	var files: Array[String] = []
	for dir in SOURCE_DIRS + MORE_SOURCE_DIRS:
		_files(dir, ["gd"] as Array[String], files)
	var literal := RegEx.create_from_string('EventLog\\.record\\(\\s*&?"')
	var offenders: Array[String] = []
	for path in files:
		if literal.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path)
	assert_array(offenders).is_empty()


func test_no_kind_is_also_a_tag() -> void:
	var files: Array[String] = []
	for dir in SOURCE_DIRS + MORE_SOURCE_DIRS:
		_files(dir, ["tscn", "tres"] as Array[String], files)
	var names := RegEx.create_from_string('&"([a-z_]+\\.[a-z_.]+)"')
	var tags: Dictionary[String, String] = {}
	for path in files:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.contains("tags"):
				continue
			for found in names.search_all(line):
				tags[found.get_string(1)] = path
	var kinds := _kinds()
	for constant in kinds:
		var kind := String(kinds[constant])
		assert_bool(tags.has(kind)).override_failure_message("%s is a tag in %s" % [kind, tags.get(kind)]).is_false()
	# The scan does see tags.
	assert_bool(tags.has("actor.player")).is_true()


func test_entries_keep_entities_by_reference_and_names_for_display() -> void:
	var source := auto_free(Fixtures.entity(self, "Same", Vector3(0, -60, 0), [])) as Node3D
	var other := auto_free(Fixtures.entity(self, "Other", Vector3(0, -60, 0), [])) as Node3D
	var data := {"by": other, "count": 2}

	var entry := EventLogEntry.make(1, EventKinds.ITEM_USED, source, "Label", data)

	assert_str(entry.source).is_equal("Same")
	assert_str(entry.target).is_equal("Label")
	assert_object(entry.source_entity()).is_same(source)
	assert_object(entry.target_entity()).is_null()
	assert_object(entry.entity(&"by")).is_same(other)
	assert_str(str(entry.data["by"])).is_equal("Other")
	# The caller's dictionary is untouched.
	assert_object(data["by"]).is_same(other)
	# Renaming changes nothing about who it was.
	other.name = "Same2"
	assert_object(entry.entity(&"by")).is_same(other)


func test_a_freed_entity_reads_as_gone() -> void:
	var source := Fixtures.entity(self, "Gone", Vector3(0, -60, 0), [])
	var entry := EventLogEntry.make(1, EventKinds.ITEM_USED, source)
	source.free()

	assert_object(entry.source_entity()).is_null()
	assert_str(entry.source).is_equal("Gone")
	var late := EventLogEntry.make(2, EventKinds.ITEM_USED, source)
	assert_str(late.source).is_empty()
