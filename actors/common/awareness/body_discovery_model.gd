class_name BodyDiscoveryModel
extends RefCounted
## Pure body discovery (ADR 0071): how long a watcher has looked at each downed ally, and which ones
## it has found. Bodies are keys (a node path string in the game). While a body is seen its progress
## grows by the vision gain per second (the same gain as the suspicion meter); unseen it decays.
## At `threshold` the body is found: remembered (never found again) until forget() (it stood up).
## No scene tree.

var threshold: float = 1.0
var decay: float = 0.5
## Body key -> progress towards `threshold`, for bodies not found yet.
var progress: Dictionary[String, float] = {}
## Bodies already found.
var found: Dictionary[String, bool] = {}


func _init(p_threshold: float = 1.0, p_decay: float = 0.5) -> void:
	threshold = p_threshold
	decay = p_decay


## One tick: `seen` maps each body seen now to its gain per second. Returns the bodies found on
## this tick.
func step(delta: float, seen: Dictionary[String, float]) -> Array[String]:
	var newly: Array[String] = []
	for key in seen:
		if found.has(key):
			continue
		var value := float(progress.get(key, 0.0)) + seen[key] * delta
		if value >= threshold:
			progress.erase(key)
			found[key] = true
			newly.append(key)
		else:
			progress[key] = value
	for key: String in progress.keys():
		if seen.has(key):
			continue
		var value := float(progress[key]) - decay * delta
		if value <= 0.0:
			progress.erase(key)
		else:
			progress[key] = value
	return newly


func is_found(key: String) -> bool:
	return found.has(key)


## The body can act again (woken): it may be found again if it goes down later.
func forget(key: String) -> void:
	found.erase(key)
	progress.erase(key)


func to_dict() -> Dictionary:
	return {"progress": progress.duplicate(), "found": found.keys()}


func from_dict(data: Dictionary) -> void:
	progress.clear()
	found.clear()
	var saved_progress: Dictionary = data.get("progress", {})
	for key: Variant in saved_progress:
		progress[String(key)] = float(saved_progress[key])
	var saved_found: Array = data.get("found", [])
	for key: Variant in saved_found:
		found[String(key)] = true
