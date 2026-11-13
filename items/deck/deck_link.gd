class_name DeckLink
extends RefCounted
## Part of DeckSession (Q17, ADR 0140): the deck's connection. Which device the deck is plugged into
## or joined over Wi-Fi (`port`), its traffic (`source`), the deck stack in use and why it was last
## unplugged; what a connection to a device would be (source_for()) and why the current one must
## drop (check()). DeckSession coordinates: it logs, signals, refreshes the map and closes screens.
## - Plugging: the port decides the address (NetworkSource): a wall jack joins its subnet, a
##   maintenance port links to its device only, a computer lends its address. Tethered: it drops
##   when its user walks further than `config.tether_distance` from the plugged entity (horizontal),
##   can no longer act, or the deck leaves the user's inventory.
## - Wi-Fi (M12b, ADR 0117): an access point (a Device with an AccessPoint) is joined once the user
##   knows its key and stands within range (wireless_range(): DeckConfig.wireless_range plus the
##   Computer skill's `deck_wireless_range`, straight line from the eye); it drops out of range
##   (`out_of_range`) and while a jamming field covers the user or the access point (`jammed`, M14b;
##   it cannot join then either).

## The Computer skill's addition to the deck's Wi-Fi range (m).
const WIRELESS_RANGE_ATTRIBUTE: StringName = &"deck_wireless_range"

## The device the deck is plugged into (null: unplugged): its entry point (a jack: the jack itself).
var port: Device
## Its traffic's source while plugged in.
var source: NetworkSource
## The deck stack plugged in.
var stack: ItemStack
## Why the deck was last unplugged.
var unplug_reason: StringName = &""


func is_plugged() -> bool:
	return port != null and is_instance_valid(port)


## True when the deck is joined to an access point's Wi-Fi (not plugged into a port).
func is_wireless() -> bool:
	return is_plugged() and source != null and source.kind == NetworkSource.Kind.WIRELESS


## True when `next` (a source_for() result) is the Wi-Fi the deck is already joined to: joining it
## again changes nothing.
func is_current(next: NetworkSource) -> bool:
	return next != null and next.kind == NetworkSource.Kind.WIRELESS and is_wireless() and port == next.device


## Takes the connection `next` (source_for()) with `deck_stack`.
func attach(next: NetworkSource, deck_stack: ItemStack) -> void:
	port = next.device
	source = next
	stack = deck_stack
	unplug_reason = &""


## Drops the connection, remembering `reason`.
func detach(reason: StringName) -> void:
	unplug_reason = reason
	port = null
	source = null
	stack = null


## The traffic `user`'s deck (`deck_stack`) would have plugged into `device` (an access point:
## joined over its Wi-Fi), or null when it cannot: no deck, no port, or (Wi-Fi) the key unknown, out
## of range or jammed.
static func source_for(user: Node, device: Device, deck_stack: ItemStack, config: DeckConfig) -> NetworkSource:
	if deck_stack == null or device == null or not is_instance_valid(device):
		return null
	var radio := AccessPoint.of(device)
	if radio != null:
		if not radio.knows_key(user) or not in_range(user, device, config) or jammed(user, device):
			return null
		return NetworkSource.wireless(user, device)
	var kind := DeviceNetwork.port_kind(device)
	if kind == NetworkSource.Kind.NONE or kind == NetworkSource.Kind.AUTO:
		return null
	return NetworkSource.for_user(user, device, kind)


## Why the connection must drop now for `user` (gone, cannot_act, no_deck, walked_away, jammed,
## out_of_range), or &"". `carried`: the deck stack is still in the user's inventory.
func check(user: Node, config: DeckConfig, carried: bool) -> StringName:
	if not is_instance_valid(port) or not is_instance_valid(port.entity) or port.entity.is_queued_for_deletion():
		return &"gone"
	if not is_instance_valid(user) or not ActorState.can_act(user):
		return &"cannot_act"
	if not carried:
		return &"no_deck"
	return _wifi_check(user, config) if is_wireless() else _tether_check(user, config)


# Why the deck's Wi-Fi must drop now (jammed, out_of_range), or &"".
func _wifi_check(user: Node, config: DeckConfig) -> StringName:
	if jammed(user, port):
		return &"jammed"
	return &"" if in_range(user, port, config) else &"out_of_range"


# Why the cable must drop now (walked_away: further than the tether, horizontally), or &"".
func _tether_check(user: Node, config: DeckConfig) -> StringName:
	var flat := (user as Node3D).global_position - port.entity.global_position
	flat.y = 0.0
	return &"walked_away" if flat.length() > config.tether_distance else &""


## True when `user` or `access_point`'s entity is jammed (`state.jammed`, ADR 0138: a deck's Wi-Fi
## link to it carries nothing).
static func jammed(user: Node, access_point: Device) -> bool:
	if access_point == null or not is_instance_valid(access_point) or not is_instance_valid(access_point.entity):
		return false
	if user != null and is_instance_valid(user) and ActorState.is_jammed(user):
		return true
	return ActorState.is_jammed(access_point.entity)


## The deck's Wi-Fi range for `user` (m): `config`'s base plus the user's Computer skill.
static func wireless_range(user: Node, config: DeckConfig) -> float:
	var base := config.wireless_range if config != null else 8.0
	return Attributes.read(user, WIRELESS_RANGE_ATTRIBUTE, base)


## Where `user` looks from: its Eyes' view (the player's camera), else its origin.
static func eye_of(user: Node) -> Vector3:
	if user == null or not is_instance_valid(user):
		return Vector3.ZERO
	if Eyes.of(user) != null:
		return Eyes.view_of(user).origin
	return (user as Node3D).global_position if user is Node3D else Vector3.ZERO


## Straight-line distance from `user`'s eye to `device`'s entity (m; INF when either is gone).
static func distance(user: Node, device: Device) -> float:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return INF
	if user == null or not is_instance_valid(user) or not device.entity.is_inside_tree():
		return INF
	return eye_of(user).distance_to(device.entity.global_position)


## True when `device` stands within `user`'s deck Wi-Fi range (`config`'s base plus the skill).
static func in_range(user: Node, device: Device, config: DeckConfig) -> bool:
	return distance(user, device) <= wireless_range(user, config)
