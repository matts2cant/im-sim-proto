class_name DeviceGraph
extends RefCounted
## Pure reach logic of the physical device network (ADR 0077): nodes are devices (switches are
## devices too), each up (powered and unbroken) or down; links are cables, undirected. A device
## reaches another when a path of links joins them whose every node, both ends included, is up.
## No scene tree: Device builds one from the level (Device.graph()) for each query.

# Node id -> up.
var _up: Dictionary[int, bool] = {}
# Node id -> ids it is cabled to (both directions are stored).
var _links: Dictionary[int, PackedInt64Array] = {}


## Adds node `id` (or updates whether it is up).
func add_node(id: int, up: bool) -> void:
	_up[id] = up
	if not _links.has(id):
		_links[id] = PackedInt64Array()


## Cables `a` and `b` (undirected). A node not added yet counts as down until it is added.
func link(a: int, b: int) -> void:
	if a == b:
		return
	_link_one_way(a, b)
	_link_one_way(b, a)


func has_node(id: int) -> bool:
	return _up.has(id)


func is_up(id: int) -> bool:
	return _up.get(id, false)


## True when `from` reaches `to`: both up and joined by links through up nodes only. A node that is
## up reaches itself.
func reaches(from: int, to: int) -> bool:
	if not is_up(from) or not is_up(to):
		return false
	return from == to or reachable(from).has(to)


## Every up node `from` reaches, in breadth-first order, `from` itself excluded; empty when `from`
## is down.
func reachable(from: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	if not is_up(from):
		return found
	var seen := {from: true}
	var queue := PackedInt64Array([from])
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next: int in _links.get(current, PackedInt64Array()):
			if seen.has(next) or not is_up(next):
				continue
			seen[next] = true
			queue.append(next)
			found.append(next)
	return found


## Every node joined to `from` by links through up nodes, the last node up or down: reachable()
## plus the down nodes cabled to `from` or to one of those (seen from `from`, they are there but
## dead). Breadth-first, `from` excluded; empty when `from` is down.
func connected(from: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	if not is_up(from):
		return found
	var seen := {from: true}
	var queue := PackedInt64Array([from])
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next: int in _links.get(current, PackedInt64Array()):
			if seen.has(next) or not has_node(next):
				continue
			seen[next] = true
			found.append(next)
			if is_up(next):
				queue.append(next)
	return found


## Every node joined to `from` by links, up or down (the physical network, what the cables still
## join), in breadth-first order, `from` excluded. Empty when `from` is not a node.
func component(from: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	if not has_node(from):
		return found
	var seen := {from: true}
	var queue := PackedInt64Array([from])
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next: int in _links.get(current, PackedInt64Array()):
			if seen.has(next) or not has_node(next):
				continue
			seen[next] = true
			queue.append(next)
			found.append(next)
	return found


## The nodes `id` is cabled to (added nodes only).
func neighbours(id: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	for next: int in _links.get(id, PackedInt64Array()):
		if has_node(next):
			found.append(next)
	return found


func _link_one_way(from: int, to: int) -> void:
	var neighbours: PackedInt64Array = _links.get(from, PackedInt64Array())
	if not neighbours.has(to):
		neighbours.append(to)
	# Packed arrays are values: store the copy back.
	_links[from] = neighbours
