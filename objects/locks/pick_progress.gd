class_name PickProgress
extends RefCounted
## Pure hold-to-pick timer (the M8 lockpicking placeholder, ADR 0078): time builds up while the pick
## is held, letting go resets it, reaching `required` seconds opens the lock.

var required: float = 1.0
var elapsed: float = 0.0


func _init(p_required: float = 1.0) -> void:
	required = p_required


## Adds `delta` seconds of holding; true once the required time is reached.
func advance(delta: float) -> bool:
	elapsed += maxf(delta, 0.0)
	return is_done()


func is_done() -> bool:
	return elapsed >= required


## 0..1 of the required time.
func fraction() -> float:
	if required <= 0.0:
		return 1.0
	return clampf(elapsed / required, 0.0, 1.0)


func reset() -> void:
	elapsed = 0.0
