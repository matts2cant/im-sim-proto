class_name EventLogEntry
extends RefCounted
## One recorded gameplay event. Scenario tests assert on sequences of these; gameplay consumers
## read them as they are added (EventLog.entry_added), never from the buffer's history (ADR 0136).
## `source`, `target` and data values are display names (debug panel, tests). The entities they
## name are kept as references (instance ids, never names): `entity(role)` returns the live entity
## of the role `source`, `target` or a data key whose value was an entity when recorded (make()),
## so consumers attribute by the entity's tags or components, never by its name.

const SOURCE: StringName = &"source"
const TARGET: StringName = &"target"

var tick: int
var kind: StringName
var source: String
var target: String
var data: Dictionary
## Role (`source`, `target` or a data key) -> instance id of the entity it named.
var entity_ids: Dictionary[StringName, int] = {}


func _init(p_tick: int, p_kind: StringName, p_source: String, p_target: String = "", p_data: Dictionary = {}) -> void:
	tick = p_tick
	kind = p_kind
	source = p_source
	target = p_target
	data = p_data


## An entry whose `p_source`, `p_target` and data values may be entities (Nodes) or display names.
## Entities are stored as their name (the data is copied first, the caller's dictionary is
## untouched) and remembered by instance id for entity(). A freed source or target reads as "".
## Other data values (numbers, strings, resources) are kept as they are.
static func make(
	p_tick: int, p_kind: StringName, p_source: Variant, p_target: Variant = "", p_data: Dictionary = {}
) -> EventLogEntry:
	var entry := EventLogEntry.new(p_tick, p_kind, "", "", p_data)
	entry.source = entry._keep(SOURCE, p_source)
	entry.target = entry._keep(TARGET, p_target)
	var copied := false
	for key: Variant in p_data:
		var value: Variant = p_data[key]
		if typeof(value) != TYPE_OBJECT or not is_instance_valid(value) or not (value is Node):
			continue
		if not copied:
			entry.data = p_data.duplicate()
			copied = true
		entry.data[key] = entry._keep(StringName(str(key)), value)
	return entry


## The live entity recorded for `role` (SOURCE, TARGET or a data key), or null (none recorded,
## or freed since).
func entity(role: StringName) -> Node:
	var id: int = entity_ids.get(role, 0)
	if id == 0:
		return null
	return instance_from_id(id) as Node


func source_entity() -> Node:
	return entity(SOURCE)


func target_entity() -> Node:
	return entity(TARGET)


func _to_string() -> String:
	var text := "[%d] %s %s" % [tick, kind, source]
	if not target.is_empty():
		text += " -> %s" % target
	if not data.is_empty():
		text += " %s" % JSON.stringify(data)
	return text


# The display name of `value`; an entity is remembered under `role`.
func _keep(role: StringName, value: Variant) -> String:
	if typeof(value) != TYPE_OBJECT:
		return str(value) if value != null else ""
	if not is_instance_valid(value):
		return ""
	var node := value as Node
	if node == null:
		return str(value)
	entity_ids[role] = node.get_instance_id()
	return String(node.name)
