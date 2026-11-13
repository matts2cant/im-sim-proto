class_name NetworkState
extends RefCounted
## The network-state rule (ADR 0122, ADR 0130), in one place: what a device's status light shows
## (StatusLight), what the interaction frame says (TargetStatus) and the deck Map's status square
## (NetworkRow) all read it. Pure over the devices given; the colours are StatusLight.COLORS.
## - A device is on a network when it has links (cables either way, the access point it reaches by
##   radio, an access point's wireless clients) or names an access point (out of range: cut off).
## - It still has its network when one of the network gear it is linked to is up; linked to no gear,
##   when one of its links is up; linked to nothing, unless it names an access point.
## - Its state: DARK unpowered (or gone), DISABLED broken or switched off by a command
##   (DeviceStatus.is_disabled()), else UP with its network, CUT_OFF without.


## The devices `device` is linked to: cables both ways, the access point it links to by radio, and
## (an access point) the devices linked to it by radio.
static func links_of(device: Device) -> Array[Device]:
	var found := DeviceNetwork.cabled(device)
	var radio := device.wireless_link()
	if radio != null and not found.has(radio):
		found.append(radio)
	if AccessPoint.of(device) != null:
		for other in DeviceNetwork.wireless_devices(device):
			if not found.has(other):
				found.append(other)
	return found


## True when `device` is on a network: it has `links`, or names an access point.
static func is_networked(device: Device, links: Array[Device]) -> bool:
	return not links.is_empty() or not device.wireless.is_empty()


## True when `device` still has its network (see the class description).
static func on_network(device: Device, links: Array[Device]) -> bool:
	var live: Array[Device] = []
	for other in links:
		if is_instance_valid(other):
			live.append(other)
	if live.is_empty():
		return device.wireless.is_empty()
	var gear_linked := false
	var any_up := false
	for other in live:
		var up := other.is_up()
		if DeviceNetwork.is_network_gear(other):
			if up:
				return true
			gear_linked = true
		elif up:
			any_up = true
	return any_up and not gear_linked


## The light state of `device` linked to `links` (see the class description).
static func state_of(device: Device, links: Array[Device]) -> StatusLight.State:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return StatusLight.State.DARK
	if not device.is_powered():
		return StatusLight.State.DARK
	if device.broken or DeviceStatus.is_disabled(device.entity):
		return StatusLight.State.DISABLED
	return StatusLight.State.UP if on_network(device, links) else StatusLight.State.CUT_OFF
