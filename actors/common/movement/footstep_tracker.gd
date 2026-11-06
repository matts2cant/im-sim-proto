class_name FootstepTracker
extends RefCounted
## Counts ground distance and reports a footstep every `stride` metres.

var distance: float = 0.0


## Adds travelled ground distance; returns true when a footstep falls in this step.
func advance(travelled: float, stride: float) -> bool:
	if stride <= 0.0:
		return false
	distance += maxf(travelled, 0.0)
	if distance < stride:
		return false
	# One footstep per call even after a large jump in distance (teleport, lag spike).
	distance = fmod(distance, stride)
	return true


func reset() -> void:
	distance = 0.0
