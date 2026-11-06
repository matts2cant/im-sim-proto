class_name AlarmTimer
extends RefCounted
## Pure timer of the level alarm (ADR 0072): raised for `duration` seconds, raising again restarts
## it, it ends when the time runs out or when cleared. No scene tree.

## Seconds left (0: not raised).
var left: float = 0.0


func is_on() -> bool:
	return left > 0.0


## Raises (or raises again) for `duration` seconds from now.
func raise(duration: float) -> void:
	left = maxf(duration, 0.0)


func clear() -> void:
	left = 0.0


## Counts down; true on the tick it runs out.
func step(delta: float) -> bool:
	if left <= 0.0:
		return false
	left = maxf(left - delta, 0.0)
	return left <= 0.0
