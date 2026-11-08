class_name SightMeter
extends RefCounted
## Pure detection meter of a watching device (ADR 0079: cameras, turrets). While a target is seen
## the meter rises by the sighting's gain per second (VisionRules, the guards' rules); unseen it
## falls by `decay` per second. When it reaches 1 the device has detected: step() returns true once,
## and `detected` stays set (no new detection, so no new incident) until nothing has been seen for
## `cooldown` seconds. No scene tree.

## Float slack on the meter (sums of 1/60 s ticks).
const EPSILON: float = 0.0001

## Suspicion lost per second while nothing is seen.
var decay: float = 0.25
## Seconds unseen after a detection before another detection can happen.
var cooldown: float = 10.0
## 0 .. 1.
var meter: float = 0.0
## Set on a detection; cleared after `cooldown` seconds unseen.
var detected: bool = false
## Seconds since a target was last seen.
var unseen_time: float = 0.0


func _init(p_decay: float = 0.25, p_cooldown: float = 10.0) -> void:
	decay = p_decay
	cooldown = p_cooldown


## Advances `delta` seconds; `gain` > 0 while a target is seen (suspicion per second), 0 otherwise.
## True on the tick of a new detection.
func step(delta: float, gain: float) -> bool:
	if gain > 0.0:
		meter = minf(meter + gain * delta, 1.0)
		unseen_time = 0.0
	else:
		meter = maxf(meter - decay * delta, 0.0)
		unseen_time += delta
		if detected and unseen_time >= cooldown - EPSILON:
			detected = false
	if not detected and meter >= 1.0 - EPSILON:
		meter = 1.0
		detected = true
		return true
	return false


## Forgets everything (blinded, retargeted, power cut).
func reset() -> void:
	meter = 0.0
	detected = false
	unseen_time = 0.0


func to_dict() -> Dictionary:
	return {"meter": meter, "detected": detected, "unseen": unseen_time}


func from_dict(data: Dictionary) -> void:
	meter = float(data.get("meter", meter))
	detected = bool(data.get("detected", detected))
	unseen_time = float(data.get("unseen", unseen_time))
