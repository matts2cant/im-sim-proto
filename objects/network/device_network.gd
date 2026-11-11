class_name DeviceNetwork
extends RefCounted
## Static helpers over a Device's network data (ADR 0113): its subnet, its cables both ways, its
## trust list and how a deck plugs into it. Device keeps the reach and command API.


## `device`'s subnet: its own `subnet`, else the first cabled device's that names one (a switch,
## not a router), else &"" (the implicit subnet of a level without network data).
static func subnet_of(device: Device) -> StringName:
	if device == null or not is_instance_valid(device):
		return &""
	if not device.subnet.is_empty():
		return device.subnet
	for other in cabled(device):
		if not other.subnet.is_empty() and Router.of(other.entity) == null:
			return other.subnet
	return &""


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
## component), MAINTENANCE for a device without cables (autonomous), else NONE.
static func port_kind(device: Device) -> Device.DeckPort:
	if device == null or not is_instance_valid(device):
		return Device.DeckPort.NONE
	if device.deck_port != Device.DeckPort.AUTO:
		return device.deck_port
	if is_instance_valid(device.entity) and Computer.of(device.entity) != null:
		return Device.DeckPort.HOST
	if cabled(device).is_empty():
		return Device.DeckPort.MAINTENANCE
	return Device.DeckPort.NONE
