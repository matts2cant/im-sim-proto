extends Node
## Autoload: the event stream of gameplay events and a bounded, ordered record of them (ADR 0136).
## - Gameplay consumers (mission tallies and objectives, HUD feedback) listen to `entry_added` as
##   entries are recorded and keep what they need; they never read back through the buffer.
## - The buffer (`capacity` entries, oldest dropped first) is history for the debug panel and for
##   scenario tests to assert on.
## The kinds are game content, listed in EventKinds (`events/event_kinds.gd`) with the data keys
## consumers read; this mechanism knows none of them.

signal entry_added(entry: EventLogEntry)
signal cleared

var capacity: int = 2000

# Ring buffer: once full, _head is the index of the oldest entry.
var _buffer: Array[EventLogEntry] = []
var _head: int = 0


## Records an event of `kind`. `source` and `target` are entities (Nodes) or display names; data
## values that are Nodes are entities too: the entry keeps their names for display and the entities
## themselves for EventLogEntry.entity() (consumers attribute by tags, never by name).
func record(kind: StringName, source: Variant, target: Variant = "", data: Dictionary = {}) -> EventLogEntry:
	var entry := EventLogEntry.make(Engine.get_physics_frames(), kind, source, target, data)
	if _buffer.size() < capacity:
		_buffer.append(entry)
	else:
		_buffer[_head] = entry
		_head = (_head + 1) % capacity
	entry_added.emit(entry)
	return entry


## All retained entries, oldest first (debug and tests; gameplay listens to entry_added).
func entries() -> Array[EventLogEntry]:
	var ordered: Array[EventLogEntry] = _buffer.slice(_head)
	ordered.append_array(_buffer.slice(0, _head))
	return ordered


## Retained entries of `kind`, oldest first (debug and tests).
func find(kind: StringName) -> Array[EventLogEntry]:
	return entries().filter(func(entry: EventLogEntry) -> bool: return entry.kind == kind)


func clear() -> void:
	_buffer.clear()
	_head = 0
	cleared.emit()
