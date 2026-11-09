class_name TripwireModel
extends RefCounted
## Pure logic of a laser tripwire's trip and re-arm (ADR 0096), no scene tree. Each tick it is told
## whether something breaks the beam. The first break trips it (step() returns true once); it stays
## tripped, reporting nothing more, until the beam has been clear for `rearm_delay` seconds, so one
## crossing (however slow, or a body left lying in the beam) is one incident.

var rearm_delay: float = 1.0
## Tripped and not re-armed yet.
var tripped: bool = false
## Something breaks the beam this tick.
var blocked: bool = false
## Seconds the beam has been clear since it was last broken.
var clear_time: float = 0.0


func _init(p_rearm_delay: float = 1.0) -> void:
	rearm_delay = p_rearm_delay


## Advances `delta` seconds with the beam `broken` or clear; true when this tick trips it.
func step(delta: float, broken: bool) -> bool:
	blocked = broken
	if broken:
		clear_time = 0.0
		if tripped:
			return false
		tripped = true
		return true
	clear_time += delta
	if tripped and clear_time >= rearm_delay:
		tripped = false
	return false


## Armed and clear (a disabled or unpowered beam starts over when it comes back).
func reset() -> void:
	tripped = false
	blocked = false
	clear_time = 0.0


func to_dict() -> Dictionary:
	return {"tripped": tripped, "clear_time": clear_time}


func from_dict(data: Dictionary) -> void:
	tripped = bool(data.get("tripped", tripped))
	clear_time = float(data.get("clear_time", clear_time))
	blocked = false
