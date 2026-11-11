class_name AccessPoint
extends Node
## Component (M12b, ADR 0115, 0117): makes its entity's Device a Wi-Fi access point. Network gear like
## a switch: powered and breakable through its Device, cabled into one subnet (a switch or a router),
## never linked wirelessly itself. Any other device names it in its Device's `wireless` and links to
## it by radio instead of a cable while it stands within `wireless_range` (Device.wireless_link()):
## the link is part of the reach graph, so breaking or unpowering the access point takes its wireless
## devices offline as a cut cable would.
## Its Wi-Fi key is a password with a strength (DeviceAccount.Strength). A deck in hand aimed at it
## (LMB, the ranged tool interface: accepts_ranged_tool(); within reach, accepts_tool()) works it
## through the user's WirelessTool: the Wi-Fi key screen, the Icebreaker cracking the key, joining its
## subnet over Wi-Fi once the user knows the key (knows_key(), saved). A deck joined over Wi-Fi gets
## `client_address` on the access point's subnet (deck_address()).
## EventLog: `network.wifi_key {device, by}` when a user learns the key. Saveable (who knows it).

## `by_key` learned the key.
signal key_learned(by_key: String)

## How far its radio reaches a wireless device (m, centre to centre: the entities' origins).
@export var wireless_range: float = 15.0
## The Wi-Fi key and how hard it is to brute-force (the Icebreaker's base times).
@export var key: String = ""
@export var key_strength: DeviceAccount.Strength = DeviceAccount.Strength.WEAK
## The address a deck joined over Wi-Fi gets; empty: its own address with the last number 200.
@export var client_address: String = ""
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device

# User keys (NetworkSource.user_key()) that know the key.
var _known: PackedStringArray = PackedStringArray()


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null:
		push_warning("AccessPoint %s: needs a Device on its entity" % get_path())


## The AccessPoint component on `node` (an entity, or its Device), or null.
static func of(node: Node) -> AccessPoint:
	if node == null or not is_instance_valid(node):
		return null
	if node is AccessPoint:
		return node as AccessPoint
	var holder := node
	if node is Device and is_instance_valid((node as Device).entity):
		holder = (node as Device).entity
	for child in holder.get_children():
		if child is AccessPoint:
			return child as AccessPoint
	return null


## True when a device at `position` (its entity's origin) is within its radio range.
func covers(position: Vector3) -> bool:
	return is_instance_valid(entity) and entity.global_position.distance_to(position) <= wireless_range


## The address a deck joined over Wi-Fi gets on its subnet.
func deck_address() -> String:
	if not client_address.is_empty():
		return client_address
	var own := device.address if device != null else ""
	var dot := own.rfind(".")
	if dot < 0:
		return "wifi:" + own if not own.is_empty() else "wifi"
	return own.left(dot + 1) + "200"


## True when `by` knows the key (cracked it).
func knows_key(by: Node) -> bool:
	var who := NetworkSource.user_key(by)
	return not who.is_empty() and _known.has(who)


## `by` now knows the key.
func grant_key(by: Node) -> void:
	var who := NetworkSource.user_key(by)
	if who.is_empty() or _known.has(who):
		return
	_known.append(who)
	var device_name := String(entity.name) if is_instance_valid(entity) else String(name)
	EventLog.record(&"network.wifi_key", who, device_name, {"device": device_name, "by": who})
	key_learned.emit(who)


## Tool interface (ToolUse): the deck works it within reach as from afar.
func accepts_tool(tool: StringName) -> bool:
	return tool == Device.DECK_TOOL


## Ranged tool interface (ToolUse): the deck aimed at it from afar (its user's WirelessTool decides
## what happens: the range is the user's).
func accepts_ranged_tool(tool: StringName, user: Node) -> bool:
	return tool == Device.DECK_TOOL and WirelessTool.of(user) != null


## Working it with the deck aims the user's WirelessTool at it (the Wi-Fi key screen, or joining).
func tool_hold(user: Node, _delta: float) -> bool:
	var wireless := WirelessTool.of(user)
	if wireless != null and device != null:
		wireless.aim(device)
	return false


func tool_release(_user: Node) -> void:
	pass


func save_state() -> Dictionary:
	return {"known": Array(_known)}


func load_state(data: Dictionary) -> void:
	if data.has("known"):
		_known = PackedStringArray(data["known"] as Array)
