class_name DeviceGraphBuilder
extends RefCounted
## Builds the reach graph (DeviceGraph, pure logic) of every device in a level for one query (ADR
## 0077, 0113, 0117, 0131): nodes are Device instance ids, up when Device.is_up(); links are cables
## (Device.linked()) and holding wireless links (Device.wireless_link()); each node's subnet (its own,
## else a cabled non-gate device's that names one, a wireless device's its access point's); routers
## (Router) are gates. Device keeps the device's own concerns (state, cables, commands).


## The reach graph of every device in `tree`, with subnets and routers.
## `source`: the user traffic comes from (a deck, ADR 0113): its start node (source.start_id())
## speaks with its user's rights at the gates; a deck on a wall jack is a node of its own
## (Device.DECK_NODE) cabled to the jack. Without a source every node speaks for its own device.
## `physical`: wireless links as the range allows them, jammed or not (DeviceNetwork.physical_network:
## the Map); else only the live ones (not DeviceNetwork.is_jammed()).
static func build(tree: SceneTree, source: NetworkSource = null, physical: bool = false) -> DeviceGraph:
	var result := DeviceGraph.new()
	var devices := Device.all(tree)
	for device in devices:
		var id := device.get_instance_id()
		result.add_node(id, device.is_up())
		var router := Router.of(device.entity)
		if router != null:
			result.set_gate(id, _gate(router, source, result))
	# Device -> the access point it links to by radio (valid links only; jammed ones too: the subnet
	# stays the access point's, only the link is not in a live graph).
	var radio: Dictionary[Device, Device] = {}
	for device in devices:
		for other in device.linked():
			result.link(device.get_instance_id(), other.get_instance_id())
		var access_point := device.wireless_link()
		if access_point != null:
			radio[device] = access_point
			if physical or not DeviceNetwork.is_jammed(device):
				result.link(device.get_instance_id(), access_point.get_instance_id())
	for device in devices:
		var id := device.get_instance_id()
		var own := device.subnet
		if own.is_empty():
			for next in result.neighbours(id):
				var other := instance_from_id(next) as Device
				if other != null and not other.subnet.is_empty() and not result.is_gate(next):
					own = other.subnet
					break
		result.set_subnet(id, own)
	# A wireless device without a subnet of its own is on its access point's.
	for device: Device in radio:
		if device.subnet.is_empty():
			result.set_subnet(device.get_instance_id(), result.subnet_of(radio[device].get_instance_id()))
	if source != null and source.start_id() == Device.DECK_NODE and is_instance_valid(source.device):
		result.add_node(Device.DECK_NODE, true)
		result.set_subnet(Device.DECK_NODE, source.subnet)
		result.link(Device.DECK_NODE, source.device.get_instance_id())
	return result


# The gate of `router`: Router.passes() for the traffic's source (the user's at the source's start
# node, else the sending device's) and its final destination.
static func _gate(router: Router, source: NetworkSource, network: DeviceGraph) -> Callable:
	var senders: Dictionary[int, NetworkSource] = {}
	return func(from: int, to: int) -> bool:
		var sender := source if source != null and from == source.start_id() else null
		if sender == null:
			sender = senders.get(from, null)
		if sender == null:
			sender = NetworkSource.of_device(instance_from_id(from) as Device, network.subnet_of(from))
			senders[from] = sender
		return router.passes(sender, instance_from_id(to) as Device)
