class_name NetworkSource
extends RefCounted
## Pure-ish: where network traffic comes from (ADR 0113). Gateways judge traffic by it (GatewayRule:
## from a subnet, a device or "you"), tracers block its address and report its entry point.
## - DEVICE: a device speaking for itself (an alarm controller ringing a siren); no user.
## - JACK: a deck on a wall jack: its own graph node (Device.DECK_NODE) on the jack's subnet; the
##   jack's address (the deck's address on that subnet).
## - PORT: a deck on a device's maintenance port: a direct link to that device only.
## - HOST: a deck plugged into a computer: the computer's address, from the computer's node.
## - BARE: a user at a computer bare-handed (its own desktop only): the computer's address.
## "You" (a user) is any source with a user.

enum Kind { DEVICE, JACK, PORT, HOST, BARE }

var kind: Kind = Kind.DEVICE
## The device the traffic starts at or enters through (the sender, the jack, the port's device, the
## host computer).
var device: Device
## Who operates (null for a device's own traffic).
var user: Node
var address: String = ""
var subnet: StringName = &""


## A device's own traffic; `p_subnet`: its subnet when already known (a graph's), else looked up.
static func of_device(p_device: Device, p_subnet: StringName = &"") -> NetworkSource:
	var source := NetworkSource.new()
	source.kind = Kind.DEVICE
	source.device = p_device
	if p_device != null and is_instance_valid(p_device):
		source.address = p_device.address
		source.subnet = p_subnet if not p_subnet.is_empty() else DeviceNetwork.subnet_of(p_device)
	return source


## `p_user`'s traffic entering through `p_device` as `p_kind` (JACK, PORT, HOST or BARE).
static func for_user(p_user: Node, p_device: Device, p_kind: Kind) -> NetworkSource:
	var source := NetworkSource.of_device(p_device)
	source.kind = p_kind
	source.user = p_user
	if p_kind == Kind.PORT and p_device != null:
		source.address = "port:" + (p_device.address if not p_device.address.is_empty() else display_name(p_device))
	return source


## The key a user is known by (accounts, traces): its node name.
static func user_key(p_user: Node) -> String:
	return String(p_user.name) if p_user != null and is_instance_valid(p_user) else ""


## How screens name a device: its entity's `display_name` metadata ("FW-01"), else its node name in
## words ("OfficePc2" -> "Office Pc 2").
static func display_name(p_device: Device) -> String:
	if p_device == null or not is_instance_valid(p_device):
		return ""
	if not is_instance_valid(p_device.entity):
		return String(p_device.name)
	if p_device.entity.has_meta(&"display_name"):
		return str(p_device.entity.get_meta(&"display_name"))
	return String(p_device.entity.name).capitalize()


## A user's traffic ("you" in a gateway rule).
func is_user() -> bool:
	return user != null and is_instance_valid(user)


## The graph node the traffic starts at (Device.graph()): DECK_NODE on a jack, else the device's.
func start_id() -> int:
	if kind == Kind.JACK:
		return Device.DECK_NODE
	return device.get_instance_id() if is_instance_valid(device) else 0


## Where an incident about this traffic is reported (the entry point), or Vector3.ZERO.
func entry_point() -> Vector3:
	if is_instance_valid(device) and is_instance_valid(device.entity):
		return device.entity.global_position
	return Vector3.ZERO


## The devices this traffic reaches now (breadth-first; a maintenance port: its device only, while
## up). The start device itself is included unless it is a jack's switch reached by the deck node
## (then it is just the first hop).
func reached(tree: SceneTree) -> Array[Device]:
	return _devices(tree, false)


## reached() plus the down devices right behind a reached one (DeviceGraph.connected()): what a map
## shows, the dead ones greyed.
func connected(tree: SceneTree) -> Array[Device]:
	return _devices(tree, true)


## True when this traffic reaches `target` now.
func reaches(tree: SceneTree, target: Device) -> bool:
	if tree == null or not is_instance_valid(target) or not is_instance_valid(device):
		return false
	if kind == Kind.PORT:
		return target == device and device.is_up()
	if target == device and kind != Kind.JACK:
		return device.is_up()
	return Device.graph(tree, self).reaches(start_id(), target.get_instance_id())


func _devices(tree: SceneTree, with_down: bool) -> Array[Device]:
	var found: Array[Device] = []
	if tree == null or not is_instance_valid(device):
		return found
	if kind == Kind.PORT:
		if device.is_up() or with_down:
			found.append(device)
		return found
	if kind != Kind.JACK:
		if not device.is_up():
			return found
		found.append(device)
	var graph := Device.graph(tree, self)
	var ids := graph.connected(start_id()) if with_down else graph.reachable(start_id())
	for id in ids:
		var other := instance_from_id(id) as Device
		if other != null and not found.has(other):
			found.append(other)
	return found
