class_name TracerMotion
extends RefCounted
## Pure (ADR 0126): where a tracer's bright streak is `age` seconds after the shot. Its head leaves
## `start` (the muzzle) at `speed` m/s towards `end` (the hit point); the tail follows `length`
## metres behind, never behind the start; once the head arrives the streak stays and fades over
## `fade` seconds.

var start: Vector3
var end: Vector3
var speed: float
var length: float
var fade: float


func _init(p_start: Vector3, p_end: Vector3, p_speed: float, p_length: float, p_fade: float) -> void:
	start = p_start
	end = p_end
	speed = maxf(p_speed, 0.001)
	length = maxf(p_length, 0.0)
	fade = maxf(p_fade, 0.0)


func distance() -> float:
	return start.distance_to(end)


## Seconds the head takes from the muzzle to the end.
func travel_time() -> float:
	return distance() / speed


## Tail and head of the streak at `age` (world points).
func segment(age: float) -> PackedVector3Array:
	var total := distance()
	if total <= 0.0:
		return PackedVector3Array([end, end])
	var head := clampf(age * speed, 0.0, total)
	var tail := clampf(head - length, 0.0, total)
	return PackedVector3Array([start.lerp(end, tail / total), start.lerp(end, head / total)])


## Opacity at `age`: 1 in flight, down to 0 over `fade` after the head arrived.
func alpha(age: float) -> float:
	var past := age - travel_time()
	if past <= 0.0:
		return 1.0
	if fade <= 0.0:
		return 0.0
	return clampf(1.0 - past / fade, 0.0, 1.0)


func is_done(age: float) -> bool:
	return age >= travel_time() + fade
