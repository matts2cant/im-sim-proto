class_name EventLogEntry
extends RefCounted
## One recorded gameplay event. Scenario tests assert on sequences of these.

var tick: int
var kind: StringName
var source: String
var target: String
var data: Dictionary


func _init(p_tick: int, p_kind: StringName, p_source: String, p_target: String = "", p_data: Dictionary = {}) -> void:
	tick = p_tick
	kind = p_kind
	source = p_source
	target = p_target
	data = p_data


func _to_string() -> String:
	var text := "[%d] %s %s" % [tick, kind, source]
	if not target.is_empty():
		text += " -> %s" % target
	if not data.is_empty():
		text += " %s" % JSON.stringify(data)
	return text
