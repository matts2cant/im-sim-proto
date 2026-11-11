class_name DeviceGraph
extends RefCounted
## Pure reach logic of the physical device network (ADR 0077): nodes are devices (switches are
## devices too), each up (powered and unbroken) or down; links are cables, undirected. A device
## reaches another when a path of links joins them whose every node, both ends included, is up.
## No scene tree: Device builds one from the level (Device.graph()) for each query.
## Subnets and gates (M12a, ADR 0113): each node may carry a subnet (default &"": one implicit
## subnet). A gate (a router) is a node whose crossing is decided by a Callable
## `gate(from: int, to: int) -> bool` (`from` the node the traffic starts at, `to` its final
## destination): traffic that enters a gate from one subnet and leaves it into a node of another
## subnet passes only when the gate says so; leaving on the side it came from is free, and a gate is
## always reached itself (and sends freely: it is the start). Without gates nothing changes.

# Node id -> up.
var _up: Dictionary[int, bool] = {}
# Node id -> ids it is cabled to (both directions are stored).
var _links: Dictionary[int, PackedInt64Array] = {}
# Node id -> subnet (missing: &"").
var _subnets: Dictionary[int, StringName] = {}
# Gate node id -> Callable(from: int, to: int) -> bool.
var _gates: Dictionary[int, Callable] = {}


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


## Puts node `id` on `subnet` (&"": the implicit one).
func set_subnet(id: int, subnet: StringName) -> void:
	_subnets[id] = subnet


func subnet_of(id: int) -> StringName:
	return _subnets.get(id, &"")


## Makes node `id` a gate: `gate(from, to)` decides whether traffic from `from` to `to` crosses it
## into another subnet.
func set_gate(id: int, gate: Callable) -> void:
	_gates[id] = gate


func is_gate(id: int) -> bool:
	return _gates.has(id)


func has_gates() -> bool:
	return not _gates.is_empty()


func has_node(id: int) -> bool:
	return _up.has(id)


func is_up(id: int) -> bool:
	return _up.get(id, false)


## True when `from` reaches `to`: both up and joined by links through up nodes only, every gate on
## the way letting traffic from `from` to `to` through. A node that is up reaches itself.
func reaches(from: int, to: int) -> bool:
	if not is_up(from) or not is_up(to):
		return false
	return from == to or _search(from, to).has(to)


## Every up node `from` reaches (reaches()), in breadth-first order, `from` itself excluded; empty
## when `from` is down.
func reachable(from: int) -> PackedInt64Array:
	if not is_up(from):
		return PackedInt64Array()
	if _gates.is_empty():
		return _search(from, -1)
	# Gates decide per destination: keep the up nodes of the physical network that are reached.
	var found := PackedInt64Array()
	for id in component(from):
		if is_up(id) and reaches(from, id):
			found.append(id)
	return found


## Every node joined to `from` by links through up nodes, the last node up or down: reachable()
## plus the down nodes cabled to `from` or to one of those (seen from `from`, they are there but
## dead; behind a gate only when it lets traffic to them through). Breadth-first, `from` excluded;
## empty when `from` is down.
func connected(from: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	if not is_up(from):
		return found
	var reached := reachable(from)
	var order := component(from)
	for id in order:
		if reached.has(id):
			found.append(id)
			continue
		if is_up(id):
			continue
		for next in neighbours(id):
			if next != from and not reached.has(next):
				continue
			if next == from or not is_gate(next) or (_gates[next] as Callable).call(from, id):
				found.append(id)
				break
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


# Breadth-first from `from` through up nodes and the gates that let traffic to `to` through (-1: no
# gate checks, only for a graph without gates). Stops early once `to` is found.
func _search(from: int, to: int) -> PackedInt64Array:
	var found := PackedInt64Array()
	var seen := {from: true}
	# Node id -> the subnet the traffic came from (a gate compares it with the next node's).
	var entered: Dictionary[int, StringName] = {from: subnet_of(from)}
	var queue := PackedInt64Array([from])
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		var gated := current != from and _gates.has(current)
		for next: int in _links.get(current, PackedInt64Array()):
			if seen.has(next) or not is_up(next):
				continue
			if gated and subnet_of(next) != entered[current] and not (_gates[current] as Callable).call(from, to):
				continue
			seen[next] = true
			entered[next] = subnet_of(current)
			queue.append(next)
			found.append(next)
			if next == to:
				return found
	return found


func _link_one_way(from: int, to: int) -> void:
	var neighbours: PackedInt64Array = _links.get(from, PackedInt64Array())
	if not neighbours.has(to):
		neighbours.append(to)
	# Packed arrays are values: store the copy back.
	_links[from] = neighbours
