class_name EntityNames
extends RefCounted
## Pure: the names of entities (ADR 0140). Two kinds, never mixed:
## - Log names (log_name()): the node name, for EventLog entries and debugging only. Never an
##   identity: network users are keyed by NetworkIdentity, firewall rules name addresses.
## - Display names (display_name(), device_name()): what screens and the player read. An entity's
##   `display_name` metadata; a network device (or a panel of one) by its network name. Without the
##   metadata both fall back to the node name in words; shipped content always sets it (a level test
##   lists any device, door, readable or pickup that would fall back: has_display_name()).

const META: StringName = &"display_name"


## The name logs use for `node`: its node name; `fallback`'s (the component writing the log) when
## `node` is null or freed; "" without either.
static func log_name(node: Node, fallback: Node = null) -> String:
	if node != null and is_instance_valid(node):
		return String(node.name)
	if fallback != null and is_instance_valid(fallback):
		return String(fallback.name)
	return ""


## The log name of `device`'s entity (its Device node's name when the entity is gone; "" for none).
static func device_log_name(device: Device) -> String:
	if device == null or not is_instance_valid(device):
		return ""
	return log_name(device.entity, device)


## How screens name a world entity: a network device (or a panel of one, Device.of()) by its network
## name (device_name(), as the deck's Map and its name plate show it: "SW-OFFICE"), else its
## `display_name` metadata, else its node name in words without a trailing number ("SmallCrate2" ->
## "Small crate").
static func display_name(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var device := Device.of(node)
	if device != null:
		return device_name(device)
	if node.has_meta(META):
		return str(node.get_meta(META))
	var words := String(node.name).capitalize()
	while not words.is_empty() and (words[-1].is_valid_int() or words[-1] == " "):
		words = words.left(-1)
	return words.left(1) + words.substr(1).to_lower()


## How screens name a device: its entity's `display_name` metadata ("RTR-01"), else its entity's
## node name in words ("OfficePc2" -> "Office Pc 2").
static func device_name(device: Device) -> String:
	if device == null or not is_instance_valid(device):
		return ""
	if not is_instance_valid(device.entity):
		return String(device.name)
	if device.entity.has_meta(META):
		return str(device.entity.get_meta(META))
	return String(device.entity.name).capitalize()


## True when `node` has a player-facing name of its own (`display_name` metadata on it, or on the
## entity of the device it stands for) instead of a fallback built from a node name.
static func has_display_name(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var device := Device.of(node)
	if device != null and is_instance_valid(device.entity):
		return device.entity.has_meta(META)
	return node.has_meta(META)
