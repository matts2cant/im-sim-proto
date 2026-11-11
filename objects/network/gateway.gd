class_name Gateway
extends Node
## Component (ADR 0074, 0113): makes its entity's Device a gateway (a firewall) between subnets. The
## reach graph (Device.graph()) asks passes() whenever traffic enters it from one subnet and leaves
## into another: its `rules` first (GatewayRule, first match wins); without a match a device's own
## traffic passes when `default_allow`, a user's (the deck: "you") only when that user has an account
## on this gateway (DeviceAccounts.has_access(): "hacking the gateway"). So the subnets behind a
## gateway stay out of a deck's reach, and off its map, until it is hacked.
## Saveable: the rules (M12b's Firewall edits them).

## Rules, in order: the first that matches wins.
@export var rules: Array[GatewayRule] = []
## Device traffic (cameras reporting, controllers ringing) without a matching rule passes.
@export var default_allow: bool = true
@export var entity_path: NodePath = ^".."

var entity: Node


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path)


## The Gateway component of `node` (an entity), or null.
static func of(node: Node) -> Gateway:
	if node == null or not is_instance_valid(node):
		return null
	if node is Gateway:
		return node as Gateway
	for child in node.get_children():
		if child is Gateway:
			return child as Gateway
	return null


## True when traffic from `source` to `destination` crosses this gateway (see the class description).
func passes(source: NetworkSource, destination: Device) -> bool:
	for rule in rules:
		if rule != null and rule.matches(source, destination):
			return rule.allow
	if source != null and source.is_user():
		var accounts := DeviceAccounts.of(entity)
		return accounts != null and accounts.has_access(source.user)
	return default_allow


## The subnets this gateway joins (its cabled devices' subnets and its own), in cable order.
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
		var loaded: Array[GatewayRule] = []
		for item: Variant in data["rules"] as Array:
			loaded.append(GatewayRule.from_dict(item as Dictionary))
		rules = loaded
	default_allow = bool(data.get("default_allow", default_allow))
