class_name ShotStats
extends RefCounted
## Pure logic of the shooting range's stats board (ADR 0125): per target, the last `window`
## projectiles aimed at it, each a hit (with its point in the target's own frame) or a miss. Hit
## share = hits / shots; group size = the largest distance between two hits (extreme spread, the
## usual group measure), in the target's frame so a moving target's group stays put.

## Projectiles kept per target.
var window: int = 10

# key -> Array of [hit: bool, point: Vector3], oldest first.
var _shots: Dictionary[StringName, Array] = {}


func _init(p_window: int = 10) -> void:
	window = maxi(p_window, 1)


## Records one projectile at `key`: a hit at `point` (target frame), or a miss.
func record(key: StringName, hit: bool, point: Vector3 = Vector3.ZERO) -> void:
	if not _shots.has(key):
		_shots[key] = []
	var list: Array = _shots[key]
	list.append([hit, point])
	while list.size() > window:
		list.pop_front()


func shots(key: StringName) -> int:
	return (_shots.get(key, []) as Array).size()


func hits(key: StringName) -> int:
	return hit_points(key).size()


## Hits / shots over the window (0 without shots).
func hit_share(key: StringName) -> float:
	var count := shots(key)
	return float(hits(key)) / float(count) if count > 0 else 0.0


## Largest distance (metres) between two hits in the window; 0 with fewer than two hits.
func group_size(key: StringName) -> float:
	var points := hit_points(key)
	var widest := 0.0
	for i in points.size():
		for j in range(i + 1, points.size()):
			widest = maxf(widest, points[i].distance_to(points[j]))
	return widest


## The hits' points (target frame), oldest first.
func hit_points(key: StringName) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for entry: Array in _shots.get(key, []) as Array:
		if entry[0]:
			points.append(entry[1] as Vector3)
	return points


func clear() -> void:
	_shots.clear()
