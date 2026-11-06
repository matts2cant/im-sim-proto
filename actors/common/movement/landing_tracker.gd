class_name LandingTracker
extends RefCounted
## Pure: finds a character's touchdowns from its floor state and vertical velocity, sampled once per
## physics tick after the character moved. The landing move zeroes the vertical velocity (it slid
## along the floor), so the impact speed is rebuilt from the two ticks before: the last airborne
## velocity plus one more tick of the same downward acceleration (gravity, whatever its scale). In
## free fall that is exactly the velocity the landing move started with.

var _was_grounded: bool = true
var _last_vy: float = 0.0
var _previous_vy: float = 0.0


## Feeds one tick; returns the downward impact speed (>= 0, m/s) on the tick the body touches down,
## else -1.
func step(grounded: bool, velocity_y: float) -> float:
	var impact := -1.0
	if grounded and not _was_grounded:
		# Only extrapolate a downward acceleration: a jump launch or a blast lift is not repeated.
		var acceleration := minf(_last_vy - _previous_vy, 0.0)
		impact = maxf(-(_last_vy + acceleration), 0.0)
	_was_grounded = grounded
	_previous_vy = _last_vy
	_last_vy = velocity_y
	return impact


## Forgets the history (standing still on the ground).
func reset(grounded: bool = true) -> void:
	_was_grounded = grounded
	_last_vy = 0.0
	_previous_vy = 0.0
