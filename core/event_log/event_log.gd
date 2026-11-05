extends Node
## Autoload: bounded, ordered record of gameplay events, the single source of truth
## that the debug panel displays and scenario tests assert on.

signal entry_added(entry: EventLogEntry)

var capacity: int = 2000

# Ring buffer: once full, _head is the index of the oldest entry.
var _buffer: Array[EventLogEntry] = []
var _head: int = 0


func record(kind: StringName, source: String, target: String = "", data: Dictionary = {}) -> EventLogEntry:
	var entry := EventLogEntry.new(Engine.get_physics_frames(), kind, source, target, data)
	if _buffer.size() < capacity:
		_buffer.append(entry)
	else:
		_buffer[_head] = entry
		_head = (_head + 1) % capacity
	entry_added.emit(entry)
	return entry


## All retained entries, oldest first.
func entries() -> Array[EventLogEntry]:
	var ordered: Array[EventLogEntry] = _buffer.slice(_head)
	ordered.append_array(_buffer.slice(0, _head))
	return ordered


func find(kind: StringName) -> Array[EventLogEntry]:
	return entries().filter(func(entry: EventLogEntry) -> bool: return entry.kind == kind)


func clear() -> void:
	_buffer.clear()
	_head = 0
