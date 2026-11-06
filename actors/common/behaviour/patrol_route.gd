class_name PatrolRoute
extends Node3D
## A patrol route: its Node3D children (Marker3D) in order, looped. A point's wait (seconds spent
## there before walking on) is its metadata `wait` (float), else the walker's default. A character
## follows it when its AwarenessBehaviour's `patrol_route` points here.

const WAIT_META: StringName = &"wait"


func points() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result


func size() -> int:
	return points().size()


## Global position of point `index` (wrapped round the loop).
func point(index: int) -> Vector3:
	var all := points()
	return all[posmod(index, all.size())].global_position


## Seconds to wait at point `index`: its `wait` metadata, else `default_wait`.
func wait_at(index: int, default_wait: float) -> float:
	var all := points()
	var marker := all[posmod(index, all.size())]
	if marker.has_meta(WAIT_META):
		return float(marker.get_meta(WAIT_META))
	return default_wait
