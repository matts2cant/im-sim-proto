class_name DeviceNetwork
extends RefCounted
## Static helpers over a Device's network data (ADR 0113): its subnet, its cables both ways, the
## physical network it is on, its trust list, its address and how a deck plugs into it. Device keeps
## the reach and command API.
## Network gear (M12b, ADR 0117): a device that carries traffic for others (a switch, a router, an
## access point) is tagged NETWORK_GEAR or has a Router or AccessPoint component; gear never links
## wirelessly. A wireless device without a subnet of its own is on its access point's.

## The tag of network gear (the switch, router and access point scenes carry it).
const NETWORK_GEAR: StringName = &"object.network_gear"
## The method a component offers its entity's network address through (address_of()).
const ADDRESS_METHOD: StringName = &"device_address"


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


## True when `device`'s radio link holds by range (Device.wireless_link()) but either end is jammed
## (`state.jammed`, set by a jamming field, M14b, ADR 0138): the link carries nothing while it lasts.
static func is_jammed(device: Device) -> bool:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return false
	var access_point := device.wireless_link()
	if access_point == null or not is_instance_valid(access_point.entity):
		return false
	return ActorState.is_jammed(device.entity) or ActorState.is_jammed(access_point.entity)


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
## and breakage ignored), jammed or not, and through routers whatever their rules
## (DeviceGraph.component() of the physical DeviceGraphBuilder.build()). Empty when `device` is gone or out of
## the tree. The deck's Map draws only this network around its entry point (ADR 0113 amendment).
static func physical_network(device: Device) -> Array[Device]:
	var found: Array[Device] = []
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return found
	found.append(device)
	for id in DeviceGraphBuilder.build(device.get_tree(), null, true).component(device.get_instance_id()):
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


## How a deck plugs into `device` (its `deck_port`, AUTO resolved; NetworkSource.Kind, the deck's
## traffic then has that kind): HOST for a computer (a Computer component), PORT (a maintenance port)
## for a device without cables or a wireless link (autonomous), else NONE.
static func port_kind(device: Device) -> NetworkSource.Kind:
	if device == null or not is_instance_valid(device):
		return NetworkSource.Kind.NONE
	if device.deck_port != NetworkSource.Kind.AUTO:
		return device.deck_port
	if is_instance_valid(device.entity) and Computer.of(device.entity) != null:
		return NetworkSource.Kind.HOST
	if cabled(device).is_empty() and device.wireless_link() == null:
		return NetworkSource.Kind.PORT
	return NetworkSource.Kind.NONE


## The address `node` (an entity, or its Device) has on its network, from any of its components
## offering `device_address() -> String` (the network layer's: Device.device_address()); "" when none
## says one (screens then show no address).
static func address_of(node: Node) -> String:
	var device := node as Device
	var entity: Node = device.entity if device != null else node
	if entity == null or not is_instance_valid(entity):
		return ""
	for child in entity.get_children():
		if child.has_method(ADDRESS_METHOD):
			var value := str(child.call(ADDRESS_METHOD))
			if not value.is_empty():
				return value
	return ""
