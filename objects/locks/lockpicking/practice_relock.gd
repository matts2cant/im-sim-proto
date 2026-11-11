class_name PracticeRelock
extends RefCounted
## Pure re-lock cycle of a practice lock (ADR 0107): once opened it re-locks after `delay` seconds
## with a new random pin layout (a new seed, the layout counter + 1). Real locks keep their
## `pin_seed` across retries; only practice locks re-lay their pins.

var delay: float = 3.0
## 1 for the first layout.
var layout: int = 1
## Seed of the current layout.
var pin_seed: int = 0
## Seconds left before the re-lock, or < 0 when none is pending.
var left: float = -1.0


func _init(p_delay: float = 3.0, p_seed: int = 0) -> void:
	delay = p_delay
	pin_seed = p_seed


## The lock was opened: the re-lock is due in `delay` seconds.
func opened() -> void:
	left = delay


func pending() -> bool:
	return left >= 0.0


## Advances the countdown; true on the tick it re-locks (the new seed is drawn from `rng`).
func advance(dt: float, rng: RandomNumberGenerator) -> bool:
	if left < 0.0:
		return false
	left -= dt
	if left >= 0.0:
		return false
	left = -1.0
	layout += 1
	var next := pin_seed
	while next == pin_seed:
		next = rng.randi_range(1, 99999)
	pin_seed = next
	return true


func save_state() -> Dictionary:
	return {"layout": layout, "seed": pin_seed, "left": left}


func load_state(data: Dictionary) -> void:
	layout = int(data.get("layout", layout))
	pin_seed = int(data.get("seed", pin_seed))
	left = float(data.get("left", left))
