class_name LossOfSignal
extends RefCounted
## Pure (M12c, ADR 0115): an alarm controller's supervision of the devices that report to it. The
## controller feeds update() with the devices whose incidents would reach it now (id -> name); a
## device that did at the last update and no longer does dropped (broken, unpowered or cut off): a
## trouble note. `threshold` drops within `window` seconds make a burst: fault_due() hands it over
## once (the controller raises one network fault) and starts counting again. Fewer drops stay notes
## only, so picking off one device quietly stays possible. reset() forgets who was there (the
## controller went down); the next update() only takes stock.

var window: float = 10.0
var threshold: int = 3
## Notes kept, newest last (older ones drop off).
var max_notes: int = 8
var notes: Array[Note] = []

# Device id -> name, at the last update.
var _present: Dictionary[int, String] = {}
var _baselined: bool = false
# Recent drops not yet raised: [time, id] pairs, oldest first.
var _drops: Array[Array] = []


## One trouble note: a supervised device that lost its signal at `time` (the controller's clock).
class Note:
	extends RefCounted
	var device_name: String = ""
	var time: float = 0.0
	var text: String = "lost signal"

	## "02:15  CAM-GATE  lost signal".
	func line() -> String:
		var whole := maxi(int(floor(time)), 0)
		return "%02d:%02d  %s  %s" % [floori(whole / 60.0), whole % 60, device_name, text]


## Takes stock of `present` (id -> name) at `now`; returns the ids that dropped since the last
## update (each also a note). The first update after reset() only takes stock.
func update(present: Dictionary[int, String], now: float) -> PackedInt64Array:
	var dropped := PackedInt64Array()
	if _baselined:
		for id: int in _present:
			if not present.has(id):
				dropped.append(id)
				_note(_present[id], now)
				_drops.append([now, id])
	_present = present.duplicate()
	_baselined = true
	while not _drops.is_empty() and float(_drops[0][0]) < now - window:
		_drops.pop_front()
	return dropped


## The ids of a burst (at least `threshold` drops within `window` before `now`), handed over once;
## empty otherwise.
func fault_due(now: float) -> PackedInt64Array:
	var burst := PackedInt64Array()
	for drop in _drops:
		if float(drop[0]) >= now - window:
			burst.append(int(drop[1]))
	if threshold <= 0 or burst.size() < threshold:
		return PackedInt64Array()
	_drops.clear()
	return burst


## Forgets who was there and the pending drops (the notes stay).
func reset() -> void:
	_present.clear()
	_baselined = false
	_drops.clear()


func is_watching(id: int) -> bool:
	return _present.has(id)


## The notes' lines, newest first.
func lines() -> PackedStringArray:
	var found := PackedStringArray()
	for i in range(notes.size() - 1, -1, -1):
		found.append(notes[i].line())
	return found


func to_dict() -> Dictionary:
	var saved: Array = []
	for note in notes:
		saved.append([note.device_name, note.time, note.text])
	return {"notes": saved}


func from_dict(data: Dictionary) -> void:
	notes.clear()
	for each: Variant in data.get("notes", []):
		var parts := each as Array
		if parts == null or parts.size() < 3:
			continue
		var note := Note.new()
		note.device_name = str(parts[0])
		note.time = float(parts[1])
		note.text = str(parts[2])
		notes.append(note)
	reset()


func _note(device_name: String, now: float) -> void:
	var note := Note.new()
	note.device_name = device_name
	note.time = now
	notes.append(note)
	while notes.size() > max_notes:
		notes.pop_front()
