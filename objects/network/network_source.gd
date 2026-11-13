class_name NetworkSource
extends RefCounted
## Pure-ish: where network traffic comes from (ADR 0113). Routers judge traffic by it (RouterRule:
## from a subnet, a device or "you"), tracers block its address and report its entry point.
## Kind is also how a deck plugs into a device (Device.deck_port, DeviceNetwork.port_kind(): the
## deck's traffic then has that kind; AUTO and NONE are only a device's settings). KIND_LABELS names
## the entry points (the deck's header: "OFFICE-JACK (wall jack)").
## - DEVICE: a device speaking for itself (an alarm controller ringing a siren); no user.
## - JACK: a deck on a wall jack: its own graph node (Device.DECK_NODE) on the jack's subnet; the
##   jack's address (the deck's address on that subnet).
## - PORT: a deck on a device's maintenance port: a direct link to that device only.
## - HOST: a deck plugged into a computer: the computer's address, from the computer's node.
## - BARE: a user at a computer bare-handed (its own desktop only): the computer's address.
## - WIRELESS (M12b): a deck joined to an access point's Wi-Fi: like a jack, its own graph node on
##   the access point's subnet, linked to the access point; the address AccessPoint.deck_address().
## "You" (a user) is any source with a user.

## AUTO = 0, NONE = 1, JACK = 2 are stored in scenes (wall_jack.tscn): append new kinds at the end.
enum Kind { AUTO, NONE, JACK, PORT, HOST, DEVICE, BARE, WIRELESS }

## What screens call an entry point of each kind.
const KIND_LABELS: Dictionary[Kind, String] = {
	Kind.JACK: "wall jack",
	Kind.PORT: "maintenance port",
	Kind.HOST: "computer",
	Kind.BARE: "computer",
	Kind.WIRELESS: "Wi-Fi",
}

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


## `p_user`'s deck joined to the Wi-Fi of `access_point` (a Device with an AccessPoint).
static func wireless(p_user: Node, access_point: Device) -> NetworkSource:
	var source := NetworkSource.for_user(p_user, access_point, Kind.WIRELESS)
	var radio := AccessPoint.of(access_point)
	if radio != null:
		source.address = radio.deck_address()
	return source


## What screens call an entry point of `p_kind` (KIND_LABELS; "" for a kind without one).
static func kind_label(p_kind: Kind) -> String:
	return KIND_LABELS.get(p_kind, "")


## The kind's name in logs ("JACK", "PORT").
static func kind_name(p_kind: Kind) -> String:
	return Kind.keys()[p_kind]


## The key a user is known by (accounts, traces): its node name.
static func user_key(p_user: Node) -> String:
	return String(p_user.name) if p_user != null and is_instance_valid(p_user) else ""


## How screens name a device: its entity's `display_name` metadata ("RTR-01"), else its node name in
## words ("OfficePc2" -> "Office Pc 2").
static func display_name(p_device: Device) -> String:
	if p_device == null or not is_instance_valid(p_device):
		return ""
	if not is_instance_valid(p_device.entity):
		return String(p_device.name)
	if p_device.entity.has_meta(&"display_name"):
		return str(p_device.entity.get_meta(&"display_name"))
	return String(p_device.entity.name).capitalize()


## A user's traffic ("you" in a router rule).
func is_user() -> bool:
	return user != null and is_instance_valid(user)


## True when the traffic starts at a graph node of its own (Device.DECK_NODE) linked to `device`: a
## deck on a wall jack or joined over Wi-Fi.
func has_own_node() -> bool:
	return kind == Kind.JACK or kind == Kind.WIRELESS


## The graph node the traffic starts at (DeviceGraphBuilder.build()): DECK_NODE on a jack or over Wi-Fi, else
## the device's.
func start_id() -> int:
	if has_own_node():
		return Device.DECK_NODE
	return device.get_instance_id() if is_instance_valid(device) else 0


## Where an incident about this traffic is reported (the entry point), or Vector3.ZERO.
func entry_point() -> Vector3:
	if is_instance_valid(device) and is_instance_valid(device.entity):
		return device.entity.global_position
	return Vector3.ZERO


## The devices this traffic reaches now (breadth-first; a maintenance port: its device only, while
## up). The start device itself is included unless the deck has a node of its own (a jack's switch
## or the access point is then just the first hop).
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
	if target == device and not has_own_node():
		return device.is_up()
	return DeviceGraphBuilder.build(tree, self).reaches(start_id(), target.get_instance_id())


func _devices(tree: SceneTree, with_down: bool) -> Array[Device]:
	var found: Array[Device] = []
	if tree == null or not is_instance_valid(device):
		return found
	if kind == Kind.PORT:
		if device.is_up() or with_down:
			found.append(device)
		return found
	if not has_own_node():
		if not device.is_up():
			return found
		found.append(device)
	var graph := DeviceGraphBuilder.build(tree, self)
	var ids := graph.connected(start_id()) if with_down else graph.reachable(start_id())
	for id in ids:
		var other := instance_from_id(id) as Device
		if other != null and not found.has(other):
			found.append(other)
	return found
