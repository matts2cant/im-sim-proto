class_name Router
extends Node
## Component (ADR 0074, 0113): makes its entity's Device a router (a firewall) between subnets. The
## reach graph (Device.graph()) asks passes() whenever traffic enters it from one subnet and leaves
## into another: its `rules` first (RouterRule, first match wins); without a match a device's own
## traffic passes when `default_allow`, a user's (the deck: "you") only when that user has an account
## on this router (DeviceAccounts.has_access(): "hacking the router"). So the subnets behind a
## router stay out of a deck's reach, and off its map, until it is hacked.
## Network data (ADR 0112 amendment): `subnet_data`, the Subnets it joins (names, ranges and Map
## colours: subnet_info() gathers them from every router), and `side_addresses`, its address on each
## subnet it joins besides its Device's own (addresses(): the Map shows both).
## Saveable: the rules (M12b's Firewall edits them).

## Rules, in order: the first that matches wins.
@export var rules: Array[RouterRule] = []
## Device traffic (cameras reporting, controllers ringing) without a matching rule passes.
@export var default_allow: bool = true
@export var entity_path: NodePath = ^".."
@export_group("Network")
## The subnets it joins, as data (name, range, Map colour).
@export var subnet_data: Array[Subnet] = []
## Subnet id -> its address there, for the subnets other than its Device's (that one is Device.address).
@export var side_addresses: Dictionary[StringName, String] = {}

var entity: Node


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path)


## The Router component of `node` (an entity), or null.
static func of(node: Node) -> Router:
	if node == null or not is_instance_valid(node):
		return null
	if node is Router:
		return node as Router
	for child in node.get_children():
		if child is Router:
			return child as Router
	return null


## True when traffic from `source` to `destination` crosses this router (see the class description).
func passes(source: NetworkSource, destination: Device) -> bool:
	for rule in rules:
		if rule != null and rule.matches(source, destination):
			return rule.allow
	if source != null and source.is_user():
		var accounts := DeviceAccounts.of(entity)
		return accounts != null and accounts.has_access(source.user)
	return default_allow


## Its addresses, one per subnet it joins (subnets() order; its Device's own address on its own
## subnet, `side_addresses` on the others); subnets without one are skipped.
func addresses() -> PackedStringArray:
	var found := PackedStringArray()
	var device := Device.of(entity)
	if device == null:
		return found
	var own := DeviceNetwork.subnet_of(device)
	for each in subnets():
		var address: String = device.address if each == own else side_addresses.get(each, "")
		if not address.is_empty() and not found.has(address):
			found.append(address)
	return found


## Subnet id -> its Subnet data, from every router in `tree` (the first router naming an id wins).
static func subnet_info(tree: SceneTree) -> Dictionary[StringName, Subnet]:
	var found: Dictionary[StringName, Subnet] = {}
	for device in Device.all(tree):
		var router := Router.of(device.entity)
		if router == null:
			continue
		for data in router.subnet_data:
			if data != null and not found.has(data.id):
				found[data.id] = data
	return found


## The subnets this router joins (its cabled devices' subnets and its own), in cable order.
func subnets() -> Array[StringName]:
	var found: Array[StringName] = []
	var device := Device.of(entity)
	if device == null:
		return found
	if not device.subnet.is_empty():
		found.append(device.subnet)
	for other in DeviceNetwork.cabled(device):
		var name := DeviceNetwork.subnet_of(other)
		if not found.has(name):
			found.append(name)
	return found


func save_state() -> Dictionary:
	var data: Array[Dictionary] = []
	for rule in rules:
		if rule != null:
			data.append(rule.to_dict())
	return {"rules": data, "default_allow": default_allow}


func load_state(data: Dictionary) -> void:
	if data.has("rules"):
		var loaded: Array[RouterRule] = []
		for item: Variant in data["rules"] as Array:
			loaded.append(RouterRule.from_dict(item as Dictionary))
		rules = loaded
	default_allow = bool(data.get("default_allow", default_allow))
