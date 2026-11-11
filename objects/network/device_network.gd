class_name DeviceNetwork
extends RefCounted
## Static helpers over a Device's network data (ADR 0113): its subnet, its cables both ways, the
## physical network it is on, its trust list and how a deck plugs into it. Device keeps the reach and
## command API.
## Network gear (M12b, ADR 0117): a device that carries traffic for others (a switch, a router, an
## access point) is tagged NETWORK_GEAR or has a Router or AccessPoint component; gear never links
## wirelessly. A wireless device without a subnet of its own is on its access point's.

## The tag of network gear (the switch, router and access point scenes carry it).
const NETWORK_GEAR: StringName = &"object.network_gear"


## `device`'s subnet: its own `subnet`, else the first cabled device's that names one (a switch,
## not a router), else its access point's when it links wirelessly, else &"" (the implicit subnet of
## a level without network data).
static func subnet_of(device: Device) -> StringName:
	if device == null or not is_instance_valid(device):
		return &""
	if not device.subnet.is_empty():
		return device.subnet
	for other in cabled(device):
		if not other.subnet.is_empty() and Router.of(other.entity) == null:
			return other.subnet
	var access_point := device.wireless_link()
	if access_point != null:
		return subnet_of(access_point)
	return &""


## True when `device` is network gear: tagged NETWORK_GEAR, or a router or an access point.
static func is_network_gear(device: Device) -> bool:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return false
	var tags := ActorState.tags_of(device.entity)
	if tags != null and tags.has(NETWORK_GEAR):
		return true
	return Router.of(device.entity) != null or AccessPoint.of(device.entity) != null


## The devices linked to the access point `access_point` by radio (Device.wireless_link()).
static func wireless_devices(access_point: Device) -> Array[Device]:
	var found: Array[Device] = []
	if access_point == null or not access_point.is_inside_tree():
		return found
	for other in Device.all(access_point.get_tree()):
		if other.wireless_link() == access_point:
			found.append(other)
	return found


## The physical network `device` is on: `device` first, then every device that cables and holding
## wireless links (Device.wireless_link()) join it to, both ways, breadth-first; up or down (power
## and breakage ignored) and through routers whatever their rules (DeviceGraph.component() of
## Device.graph()). Empty when `device` is gone or out of the tree. The deck's Map draws only this
## network around its entry point (ADR 0113 amendment).
static func physical_network(device: Device) -> Array[Device]:
	var found: Array[Device] = []
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return found
	found.append(device)
	for id in Device.graph(device.get_tree()).component(device.get_instance_id()):
		var other := instance_from_id(id) as Device
		if other != null and not found.has(other):
			found.append(other)
	return found


## The devices cabled to `device`, both ways (a cable is listed on either end): linked() first.
static func cabled(device: Device) -> Array[Device]:
	var found := device.linked()
	if not device.is_inside_tree():
		return found
	for other in Device.all(device.get_tree()):
		if other != device and not found.has(other) and other.linked().has(device):
			found.append(other)
	return found


## The devices in `device`'s `trusted` list (missing ones skipped).
static func trusted(device: Device) -> Array[Device]:
	var found: Array[Device] = []
	for path in device.trusted:
		var other := Device.of(device.get_node_or_null(path))
		if other != null and not found.has(other):
			found.append(other)
	return found


## True when `sender` may command `target`: `target` has no trust list, or `sender` is on it.
static func trusts(target: Device, sender: Device) -> bool:
	return target.trusted.is_empty() or (sender != null and trusted(target).has(sender))


## How a deck plugs into `device` (Device.DeckPort, AUTO resolved): HOST for a computer (a Computer
## component), MAINTENANCE for a device without cables or a wireless link (autonomous), else NONE.
static func port_kind(device: Device) -> Device.DeckPort:
	if device == null or not is_instance_valid(device):
		return Device.DeckPort.NONE
	if device.deck_port != Device.DeckPort.AUTO:
		return device.deck_port
	if is_instance_valid(device.entity) and Computer.of(device.entity) != null:
		return Device.DeckPort.HOST
	if cabled(device).is_empty() and device.wireless_link() == null:
		return Device.DeckPort.MAINTENANCE
	return Device.DeckPort.NONE
