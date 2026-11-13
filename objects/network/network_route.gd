class_name NetworkRoute
extends RefCounted
## Pure helpers over a DeviceGraph (M12c, ADR 0115): which equipment cut a route. A route is the
## shortest path of cables (and holding radio links) between two nodes, whatever their state; the
## first down node on it is what a screen names ("RTR-01 is down") and where a network fault is
## reported. Used by AlarmController (loss of signal).


## The first down node on the shortest cabled path from `from` to `to` (`from` excluded, `to`
## included), or 0 when every node on it is up or no path joins them.
static func first_down(graph: DeviceGraph, from: int, to: int) -> int:
	for id in path(graph, from, to):
		if id != from and not graph.is_up(id):
			return id
	return 0


## The shortest cabled path from `from` to `to`, both included, up or down; empty when none.
static func path(graph: DeviceGraph, from: int, to: int) -> PackedInt64Array:
	if not graph.has_node(from) or not graph.has_node(to):
		return PackedInt64Array()
	if from == to:
		return PackedInt64Array([from])
	var parent: Dictionary[int, int] = {from: from}
	var queue := PackedInt64Array([from])
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next in graph.neighbours(current):
			if parent.has(next):
				continue
			parent[next] = current
			if next == to:
				return _unwind(parent, from, to)
			queue.append(next)
	return PackedInt64Array()


## The down node most of `dropped` share on their way from `from` (first_down() of each), when at
## least two do: the switch or router that cut them; else 0.
static func shared_cut(graph: DeviceGraph, from: int, dropped: PackedInt64Array) -> int:
	var counts: Dictionary[int, int] = {}
	var order := PackedInt64Array()
	for id in dropped:
		var cut := first_down(graph, from, id)
		if cut == 0:
			continue
		if not counts.has(cut):
			counts[cut] = 0
			order.append(cut)
		counts[cut] += 1
	var best := 0
	for cut in order:
		if counts[cut] >= 2 and (best == 0 or counts[cut] > counts[best]):
			best = cut
	return best


static func _unwind(parent: Dictionary[int, int], from: int, to: int) -> PackedInt64Array:
	var reversed := PackedInt64Array([to])
	var current := to
	while current != from:
		current = parent[current]
		reversed.append(current)
	reversed.reverse()
	return reversed
