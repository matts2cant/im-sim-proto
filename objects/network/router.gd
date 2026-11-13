class_name Router
extends Node
## Component (ADR 0074, 0113, 0116): makes its entity's Device a router (a firewall) between
## subnets. The reach graph (DeviceGraphBuilder.build()) asks passes() whenever traffic enters it from one subnet
## and leaves into another, so its rules decide everything sent over the network through it
## (commands, incidents, ringing). A device's own traffic: the first of its `rules` that matches
## (RouterRule, from a subnet, a device or any) decides, else `default_allow`. A user's (the deck:
## "you"): only rules that name "you" apply (the first match decides), else it passes when the user
## has access to this router (an account or an exploit item's grant, Device.has_access(): "hacking the
## router"). So the subnets behind a router stay out of a deck's reach, and off its map, until it is
## hacked. The deck's Firewall tool edits the rules as admin (add_rule(), move_rule(), ...).
## Network data (ADR 0112 amendment): `subnet_data`, the Subnets it joins (names, ranges and Map
## colours: subnet_info() gathers them from every router), and `side_addresses`, its address on each
## subnet it joins besides its Device's own (addresses(): the Map shows both).
## Saveable: the rules (the Firewall tool edits them). EventLog `router.rules {router, action,
## index, rules}` on every edit; an edit from the deck (a `source`) is written to the router's
## device log with its address.

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
	# Its own list: the Firewall tool edits it (rules themselves are replaced, never changed).
	rules = rules.duplicate()


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
	var user := source != null and source.is_user()
	for rule in rules:
		if rule == null or rule.names_you() != user:
			continue
		if rule.matches(source, destination):
			return rule.allow
	if user:
		var device := Device.of(entity)
		return device != null and device.has_access(source.user)
	return default_allow


## Inserts `rule` at `index` (at the end when out of range); returns its index.
func add_rule(rule: RouterRule, index: int = -1, source: NetworkSource = null) -> int:
	var at := rules.size() if index < 0 or index > rules.size() else index
	rules.insert(at, rule)
	_edited(&"add", at, source)
	return at


## Moves rule `index` by `by` places (-1: up, 1: down), clamped; returns its new index.
func move_rule(index: int, by: int, source: NetworkSource = null) -> int:
	if index < 0 or index >= rules.size():
		return index
	var to := clampi(index + by, 0, rules.size() - 1)
	if to != index:
		var rule := rules[index]
		rules.remove_at(index)
		rules.insert(to, rule)
		_edited(&"move", to, source)
	return to


## Deletes rule `index`.
func remove_rule(index: int, source: NetworkSource = null) -> void:
	if index < 0 or index >= rules.size():
		return
	rules.remove_at(index)
	_edited(&"delete", index, source)


## Replaces rule `index` with `rule` (an edited copy).
func set_rule(index: int, rule: RouterRule, source: NetworkSource = null) -> void:
	if index < 0 or index >= rules.size() or rule == null:
		return
	rules[index] = rule
	_edited(&"edit", index, source)


## Flips rule `index` between allow and deny.
func toggle_rule(index: int, source: NetworkSource = null) -> void:
	if index < 0 or index >= rules.size():
		return
	var rule := rules[index].duplicate() as RouterRule
	rule.allow = not rule.allow
	rules[index] = rule
	_edited(&"toggle", index, source)


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


# Logs an edit; one made over the network (`source`: the deck) goes to the router's own log too.
func _edited(action: StringName, index: int, source: NetworkSource) -> void:
	var router_name := EntityNames.log_name(entity, self)
	var data := {"router": router_name, "action": action, "index": index, "rules": save_state()["rules"]}
	var by := EntityNames.log_name(source.user) if source != null else ""
	EventLog.record(EventKinds.ROUTER_RULES, by, router_name, data)
	var device := Device.of(entity)
	if source != null and device != null:
		var detail := "firewall: %s rule %d" % [action, index + 1]
		device.intrusion.device_log.record(DeviceLog.REMOTE, source.address, by, detail)


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
